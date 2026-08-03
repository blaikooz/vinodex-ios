#!/usr/bin/env python3
"""Type-check the VinodexCoreTests target with the swift-testing macros stripped.

Companion to typecheck-ios-surface.sh, which does the same job for VinodexUI.
Run both before pushing.

`swift test` cannot run on this host (`no such module 'Testing'`), so the test
files are checked by nothing until CI.  This rewrites the macro surface into
plain functions — `@Test`/`@Suite` attributes dropped, `#expect`/`#require`/
`Issue.record` turned into ordinary calls — and type-checks the result against
the built VinodexCore module.  It proves the bodies compile; it cannot prove the
macro expansion does.  CI is still the gate for that.
"""
import os, re, subprocess, sys, shutil, tempfile

ROOT = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
TESTS = os.path.join(ROOT, "Tests", "VinodexCoreTests")
BINPATH = subprocess.check_output(["swift", "build", "--show-bin-path"], cwd=ROOT, text=True).strip()

SHIM = '''
// Stand-ins for the swift-testing macro surface.
// `__Comment` mirrors `Comment`: string literals and interpolations convert,
// `String` values do not — `#expect(cond, someString)` must fail here exactly
// as it fails in CI (hit 2026-08-03, EntryPaletteTests).
struct __Comment: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    init(stringLiteral _: String) {}
}
// Exactly one `__expect` overload may take the bare autoclosure condition —
// a second makes every call ambiguous.
func __expect(_ cond: @autoclosure () throws -> Bool, _ msg: @autoclosure () -> __Comment? = nil,
              sourceLocation: Int = 0) rethrows { _ = try cond(); _ = msg() }
// `#expect(throws: T.self) { … }` — the error-throwing form.
@discardableResult
func __expect<E: Error, R>(throws _: E.Type, _ msg: @autoclosure () -> __Comment? = nil,
                           sourceLocation: Int = 0,
                           performing body: () throws -> R) -> E? { _ = msg(); return nil }
struct __Unwrap: Error {}
func __require<T>(_ v: @autoclosure () throws -> T?, _ msg: @autoclosure () -> __Comment? = nil) throws -> T {
    guard let v = try v() else { throw __Unwrap() }
    return v
}
enum Issue { static func record(_ msg: __Comment? = nil) {} }
'''


def strip_attr(src, name):
    """Drop a `@Name` or `@Name(...)` attribute, balancing parens and strings."""
    out, i = [], 0
    while True:
        j = src.find("@" + name, i)
        if j < 0:
            out.append(src[i:])
            return "".join(out)
        out.append(src[i:j])
        k = j + 1 + len(name)
        # Only an attribute if what follows is `(` or whitespace-then-newline.
        while k < len(src) and src[k] in " \t":
            k += 1
        if k < len(src) and src[k] == "(":
            depth, k, in_str, raw = 0, k, False, False
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
                        k += 1
                        break
                k += 1
        i = k


def rewrite(src):
    src = strip_attr(src, "Test")
    src = strip_attr(src, "Suite")
    src = src.replace("import Testing", "")
    src = re.sub(r"#expect\(", "__expect(", src)
    src = re.sub(r"#require\(", "__require(", src)
    return src


work = tempfile.mkdtemp(prefix="vinodex-testcheck.")
files = []
for name in sorted(os.listdir(TESTS)):
    if not name.endswith(".swift"):
        continue
    with open(os.path.join(TESTS, name)) as fh:
        src = fh.read()
    dest = os.path.join(work, name)
    with open(dest, "w") as fh:
        fh.write(rewrite(src))
    files.append(dest)

shim = os.path.join(work, "__shim.swift")
with open(shim, "w") as fh:
    fh.write(SHIM)
files.append(shim)

cmd = ["swiftc", "-typecheck", "-swift-version", "6", "-I", os.path.join(BINPATH, "Modules")] + files
res = subprocess.run(cmd, capture_output=True, text=True)
noise = re.compile(
    r"parameterized|attribute 'Test'|unused|never used|was never mutated|"
    r"no 'async' operations|will never be executed"
)
lines = [l for l in res.stderr.splitlines()
         if re.search(r"\.swift:\d+:\d+: (error|warning):", l) and not noise.search(l)]
for l in lines:
    print(l.replace(work + "/", ""))
print(f"\n{len(lines)} diagnostic(s) over {len(files) - 1} test file(s).")
if os.environ.get("KEEP") != "1":
    shutil.rmtree(work)
sys.exit(1 if any("error:" in l for l in lines) else 0)
