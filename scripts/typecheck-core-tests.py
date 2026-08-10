#!/usr/bin/env python3
"""Check the VinodexCoreTests target without the `Testing` module.

Companion to typecheck-ios-surface.sh, which does the same job for VinodexUI.
Both are run **by hand**. Nothing in CI, no hook and no npm script invokes this;
CI has a real `swift test` on Linux and a real one on a simulator, so wiring
this in would only buy a slower, weaker copy of a check that already exists.

    python3 scripts/typecheck-core-tests.py          # do the bodies compile?
    python3 scripts/typecheck-core-tests.py --run    # …and do the assertions hold?

`swift test` cannot run on this host (`no such module 'Testing'`), so the test
files are checked by nothing until CI.  The default mode rewrites the macro
surface into plain functions — `@Test`/`@Suite` attributes dropped,
`#expect`/`#require`/`Issue.record` turned into ordinary calls — and type-checks
the result against the built VinodexCore module, in Swift 6 mode, which is where
CI's actor-isolation errors show up.

`--run` goes further and *executes* the suites: the same rewrite, but the
stand-ins record pass/fail, a generated call list instantiates every @Suite and
calls every @Test (expanding `arguments:`), and the whole thing links against
the already-built VinodexCore objects.  Run `swift build` first — it needs
`.build/**/VinodexCore.build/*.o`, and a stale module reads as "cannot find in
scope".

Neither mode proves the *macros expand*.  A key path passed to a `rethrows`
callee inside `#expect` compiles here and fails CI, because the real macro
decomposes the call and the shim has no macro to expand.  Traits, parallelism
and the runner's own semantics are equally out of scope.  CI is the gate.

    SELFTEST=TypeScaleTests.swift python3 scripts/typecheck-core-tests.py --run

injects one failing expectation into a real test body and expects the run to go
red.  A runner reporting zero failures because it checked nothing looks exactly
like a passing one — this is how you tell them apart, and it is the same reason
typecheck-ios-surface.sh insists on a zero-error baseline.
"""
import os, re, subprocess, sys, shutil, tempfile

ROOT = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
TESTS = os.path.join(ROOT, "Tests", "VinodexCoreTests")
BINPATH = subprocess.check_output(["swift", "build", "--show-bin-path"], cwd=ROOT, text=True).strip()

# `__Comment` mirrors `Comment` in both shims: string literals and
# interpolations convert, `String` values do not — `#expect(cond, someString)`
# must fail here exactly as it fails in CI (hit 2026-08-03, EntryPaletteTests).
# Widening it would let a call site through that CI rejects.
COMMENT = '''
struct __Comment: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    let text: String
    init(stringLiteral v: String) { text = v }
    init(stringInterpolation: DefaultStringInterpolation) { text = stringInterpolation.description }
}
'''

# Inert stand-ins, for the type-check pass.  Exactly one `__expect` overload may
# take the bare autoclosure condition — a second makes every call ambiguous.
SHIM_TYPECHECK = COMMENT + '''
func __expect(_ cond: @autoclosure () throws -> Bool, _ msg: @autoclosure () -> __Comment? = nil,
              sourceLocation: Int = 0) rethrows { _ = try cond(); _ = msg() }
// `#expect(await …)` — the real macro absorbs the effect; an autoclosure
// cannot. A separate name, not an async overload of the above, because the
// bare-autoclosure rule two comments up applies to effects too: the rewrite
// hands this one a plain Bool the caller already awaited.
func __expectAsync(_ cond: Bool, _ msg: @autoclosure () -> __Comment? = nil,
                   sourceLocation: Int = 0) { _ = msg() }
@discardableResult
func __expect<E: Error, R>(throws _: E.Type, _ msg: @autoclosure () -> __Comment? = nil,
                           sourceLocation: Int = 0,
                           performing body: () throws -> R) -> E? { _ = msg(); return nil }
// The value form — `#expect(throws: SomeError.case) { … }` — beside the type
// form above, exactly as the real API pairs them.
@discardableResult
func __expect<E: Error & Equatable, R>(throws expected: E, _ msg: @autoclosure () -> __Comment? = nil,
                                       sourceLocation: Int = 0,
                                       performing body: () throws -> R) -> E? {
    _ = expected; _ = msg(); return nil
}
struct __Unwrap: Error {}
func __require<T>(_ v: @autoclosure () throws -> T?, _ msg: @autoclosure () -> __Comment? = nil) throws -> T {
    guard let v = try v() else { throw __Unwrap() }
    return v
}
enum Issue { static func record(_ msg: __Comment? = nil) {} }
'''

# Executing stand-ins, for --run.  Same call-site signatures; different bodies.
SHIM_RUN = '''import Foundation
// The generated call list names Core types directly (`arguments:` lives in the
// @Test attribute, not the body), so this file needs its own import.
@testable import VinodexCore
''' + COMMENT + '''
final class __Recorder {
    var checks = 0, failed = 0
    var lines: [String] = []
    func pass() { checks += 1 }
    func fail(_ what: String, _ file: StaticString, _ line: UInt, _ msg: __Comment?) {
        checks += 1; failed += 1
        let f = ("\\(file)" as NSString).lastPathComponent
        lines.append("    \\(f):\\(line)  \\(what)" + (msg.map { " — \\($0.text)" } ?? ""))
    }
}
let __rec = __Recorder()

func __expect(_ cond: @autoclosure () throws -> Bool, _ msg: @autoclosure () -> __Comment? = nil,
              file: StaticString = #file, line: UInt = #line) rethrows {
    if try cond() { __rec.pass() } else { __rec.fail("expectation failed", file, line, msg()) }
}
func __expectAsync(_ cond: Bool, _ msg: @autoclosure () -> __Comment? = nil,
                   file: StaticString = #file, line: UInt = #line) {
    __expect(cond, msg(), file: file, line: line)
}
@discardableResult
func __expect<E: Error & Equatable, R>(throws expected: E, _ msg: @autoclosure () -> __Comment? = nil,
                                       file: StaticString = #file, line: UInt = #line,
                                       performing body: () throws -> R) -> E? {
    do {
        _ = try body()
        __rec.fail("expected \\(expected) to be thrown, nothing was", file, line, msg())
    } catch let error as E where error == expected {
        __rec.pass(); return error
    } catch {
        __rec.fail("expected \\(expected), got \\(error)", file, line, msg())
    }
    return nil
}
@discardableResult
func __expect<E: Error, R>(throws _: E.Type, _ msg: @autoclosure () -> __Comment? = nil,
                           file: StaticString = #file, line: UInt = #line,
                           performing body: () throws -> R) -> E? {
    let wantsNever = ObjectIdentifier(E.self) == ObjectIdentifier(Never.self)
    do {
        _ = try body()
        if wantsNever { __rec.pass(); return nil }
        __rec.fail("expected \\(E.self) to be thrown, nothing was", file, line, msg())
    } catch {
        if wantsNever { __rec.fail("expected no error, got \\(error)", file, line, msg()); return nil }
        if let e = error as? E { __rec.pass(); return e }
        __rec.fail("expected \\(E.self), got \\(error)", file, line, msg())
    }
    return nil
}
struct __Unwrap: Error, CustomStringConvertible { let description = "#require failed" }
func __require<T>(_ v: @autoclosure () throws -> T?, _ msg: @autoclosure () -> __Comment? = nil,
                  file: StaticString = #file, line: UInt = #line) throws -> T {
    guard let v = try v() else { __rec.fail("required value was nil", file, line, msg()); throw __Unwrap() }
    __rec.pass()
    return v
}
enum Issue {
    static func record(_ msg: __Comment? = nil, file: StaticString = #file, line: UInt = #line) {
        __rec.fail("Issue.record", file, line, msg)
    }
}

var __ran = 0, __failedTests = 0
var __report: [String] = []
// Many suites are @MainActor (AccessTests, AppSettingsTests, …) and top-level
// code here is nonisolated, so the call list is generated inside a @MainActor
// function and entered with assumeIsolated — main.swift already runs on the
// main thread, so the assumption is the truth rather than a workaround.
@MainActor
func __run(_ name: String, _ body: @MainActor () throws -> Void) {
    let before = __rec.failed
    var thrown: String? = nil
    do { try body() } catch { thrown = "\\(error)" }
    __ran += 1
    let mine = __rec.lines
    __rec.lines = []
    if __rec.failed > before || thrown != nil {
        __failedTests += 1
        var block = ["FAIL  " + name] + mine
        if let t = thrown, !t.contains("#require failed") { block.append("    threw: " + t) }
        __report.append(block.joined(separator: "\\n"))
    }
}
'''

EPILOGUE = '''
print("")
for block in __report { print(block); print("") }
print(String(repeating: "-", count: 60))
print("\\(__ran) tests run, \\(__ran - __failedTests) passed, \\(__failedTests) failed")
print("\\(__rec.checks) expectations checked, \\(__rec.failed) failed")
exit(__failedTests == 0 ? 0 : 1)
'''


def attr_end(src, at, name):
    """End index of `@Name` / `@Name(...)` starting at `at`, plus its inner text.

    Balances parens and string literals, so a display name containing either is
    not mistaken for the end of the attribute.
    """
    k = at + 1 + len(name)
    while k < len(src) and src[k] in " \t":
        k += 1
    if k >= len(src) or src[k] != "(":
        return k, None
    open_paren, depth, in_str, raw = k, 0, False, False
    while k < len(src):
        c = src[k]
        if in_str:
            if c == "\\" and not raw:
                k += 1
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str, raw = True, k >= 1 and src[k - 1] == "#"
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return k + 1, src[open_paren + 1:k]
        k += 1
    return k, None


def strip_attr(src, name):
    out, i = [], 0
    while True:
        j = src.find("@" + name, i)
        # `@Testable`-style false positives are not attributes.
        while j >= 0 and j + 1 + len(name) < len(src) and (
                src[j + 1 + len(name)].isalnum() or src[j + 1 + len(name)] == "_"):
            j = src.find("@" + name, j + 1)
        if j < 0:
            out.append(src[i:])
            return "".join(out)
        out.append(src[i:j])
        i, _ = attr_end(src, j, name)


def split_args(text):
    """Split on commas outside parens/brackets/strings."""
    parts, depth, in_str, raw, cur, i = [], 0, False, False, [], 0
    while i < len(text):
        c = text[i]
        if in_str:
            if c == "\\" and not raw:
                cur.append(c)
                i += 1
                if i < len(text):
                    cur.append(text[i])
                i += 1
                continue
            if c == '"':
                in_str = False
        elif c == '"':
            in_str, raw = True, i >= 1 and text[i - 1] == "#"
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif c == "," and depth == 0:
            parts.append("".join(cur)); cur = []; i += 1; continue
        cur.append(c)
        i += 1
    parts.append("".join(cur))
    return [p.strip() for p in parts if p.strip()]


def rewrite(src, selftest=False):
    src = strip_attr(strip_attr(src, "Test"), "Suite")
    src = src.replace("import Testing", "")
    # `#expect(try …)` needs no outer `try` under the real macro, which absorbs
    # the effect; as the plain `rethrows` call it becomes here, it does. The
    # outer `try` is added in the rewrite rather than in the test source —
    # the test is CI-legal as written and CI is the contract.
    src = re.sub(r"#expect\(try ", "try __expect(try ", src)
    # Same story for `await`: evaluate the condition at the call site, where
    # the effect is legal, and hand `__expectAsync` the settled Bool.
    src = re.sub(r"#expect\((try await|await) ", r"__expectAsync(\1 ", src)
    src = re.sub(r"#expect\(", "__expect(", src)
    src = re.sub(r"#require\(", "__require(", src)
    if selftest:
        src = src.replace("__expect(", '__expect(false, "SELFTEST injected"); __expect(', 1)
    return src


TYPE_RE = re.compile(r"^(?:public\s+|internal\s+|final\s+)*(?:struct|class|enum|actor)\s+(\w+)")
FUNC_RE = re.compile(r"^\s*(?:(?:private|fileprivate|internal|public|mutating|static)\s+)*func\s+(\w+)\s*\(")


def parse(src):
    """Every @Test in one file: which suite, which func, and how to call it.

    Every suite in this target is declared at column 0, so tracking the last
    column-0 type declaration is enough to place a test — a nested one would be
    misattributed and fail to compile, which is the outcome you want.
    """
    lines = src.split("\n")
    types = {n: m.group(1) for n, m in ((n, TYPE_RE.match(l)) for n, l in enumerate(lines)) if m}
    found, i = [], 0
    while True:
        j = src.find("@Test", i)
        if j < 0:
            return found
        if j + 5 < len(src) and (src[j + 5].isalnum() or src[j + 5] == "_"):
            i = j + 5
            continue
        end, inner = attr_end(src, j, "Test")
        display = args = None
        for part in split_args(inner or ""):
            if part.startswith("arguments:"):
                args = part[len("arguments:"):].strip()
            elif display is None and part.startswith('"'):
                display = part
        # First real `func` line at or after the attribute; doc comments in
        # between cannot match, so they are skipped for free.
        n, fm = src.count("\n", 0, end), None
        while n < len(lines):
            fm = FUNC_RE.match(lines[n])
            if fm:
                break
            n += 1
        if not fm:
            i = end
            continue
        sig, name = lines[n], fm.group(1)
        p = sig.index("(", fm.end(1))
        depth, k = 0, p
        while k < len(sig):
            if sig[k] == "(":
                depth += 1
            elif sig[k] == ")":
                depth -= 1
                if depth == 0:
                    break
            k += 1
        params, tail, head = sig[p + 1:k].strip(), sig[k + 1:], sig[:p]
        label = split_args(params)[0].split(":")[0].split()[0] if params else None
        found.append({
            "suite": next((types[ln] for ln in sorted(types, reverse=True) if ln < n), None),
            "func": name, "display": display, "args": args, "label": label,
            "throws": "throws" in tail, "mutating": "mutating" in head,
            "static": re.search(r"\bstatic\b", head) is not None,
        })
        i = end


def call_list(tests):
    out = []
    for t in tests:
        suite, fn = t["suite"], t["func"]
        name = ('"%s.%s — " + %s' % (suite, fn, t["display"])) if t["display"] else '"%s.%s"' % (suite, fn)
        recv = suite + "." if t["static"] else "s."
        decl = "" if t["static"] else "%s s = %s()" % ("var" if t["mutating"] else "let", suite)
        tr = "try " if t["throws"] else ""
        if t["args"]:
            arg = "a" if t["label"] == "_" else "%s: a" % t["label"]
            out.append('for a in %s {\n    __run(%s + " [\\(a)]") { %s\n        %s%s%s(%s) }\n}'
                       % (t["args"], name, decl, tr, recv, fn, arg))
        else:
            out.append('__run(%s) { %s\n    %s%s%s() }' % (name, decl, tr, recv, fn))
    return out


def main():
    run = "--run" in sys.argv[1:]
    selftest = os.environ.get("SELFTEST")
    work = tempfile.mkdtemp(prefix="vinodex-testcheck.")
    files, tests = [], []
    for fname in sorted(os.listdir(TESTS)):
        if not fname.endswith(".swift"):
            continue
        src = open(os.path.join(TESTS, fname)).read()
        if run:
            tests.extend(parse(src))
        dest = os.path.join(work, fname)
        open(dest, "w").write(rewrite(src, selftest == fname))
        files.append(dest)

    shim = os.path.join(work, "__shim.swift" if not run else "main.swift")
    if run:
        orphan = [t["func"] for t in tests if not t["suite"]]
        if orphan:
            print("could not place these tests in a suite: %s" % ", ".join(orphan), file=sys.stderr)
            return 2
        objs = sorted(f for f in os.listdir(os.path.join(BINPATH, "VinodexCore.build"))
                      if f.endswith(".o"))
        if not objs:
            print("no VinodexCore objects in %s — run `swift build` first."
                  % os.path.join(BINPATH, "VinodexCore.build"), file=sys.stderr)
            return 2
        body = "\n".join("    " + l for l in "\n".join(call_list(tests)).split("\n"))
        open(shim, "w").write(SHIM_RUN + "\n@MainActor func __runAll() {\n" + body
                              + "\n}\nMainActor.assumeIsolated { __runAll() }\n" + EPILOGUE)
        files.append(shim)
        exe = os.path.join(work, "corerunner")
        # Swift 5 mode: the suites already type-check under Swift 6 in the
        # default mode, and the generated top-level driver is simpler without
        # strict global-isolation rules it does not benefit from.
        cmd = (["swiftc", "-swift-version", "5", "-I", os.path.join(BINPATH, "Modules"), "-o", exe]
               + files + [os.path.join(BINPATH, "VinodexCore.build", o) for o in objs])
        print("compiling %d test files, %d suites, %d cases…"
              % (len(files) - 1, len({t["suite"] for t in tests}), len(tests)))
    else:
        open(shim, "w").write(SHIM_TYPECHECK)
        files.append(shim)
        cmd = ["swiftc", "-typecheck", "-swift-version", "6",
               "-I", os.path.join(BINPATH, "Modules")] + files

    res = subprocess.run(cmd, capture_output=True, text=True)
    noise = re.compile(
        r"parameterized|attribute 'Test'|unused|never used|was never mutated|"
        r"no 'async' operations|will never be executed")
    diags = [l for l in res.stderr.splitlines()
             if re.search(r"\.swift:\d+:\d+: (error|warning):", l) and not noise.search(l)]
    for l in diags:
        print(l.replace(work + "/", ""))

    if not run:
        print("\n%d diagnostic(s) over %d test file(s)." % (len(diags), len(files) - 1))
        shutil.rmtree(work)
        return 1 if any("error:" in l for l in diags) else 0

    if res.returncode != 0:
        print("\ncompile failed — KEEP=1 to inspect %s" % work, file=sys.stderr)
        return 2
    out = subprocess.run([exe], cwd=ROOT, capture_output=True, text=True)
    print(out.stdout)
    if out.stderr.strip():
        print("--- stderr ---\n" + out.stderr, file=sys.stderr)
    if os.environ.get("KEEP") == "1":
        print("kept: " + work)
    else:
        shutil.rmtree(work)
    return out.returncode


if __name__ == "__main__":
    sys.exit(main())
