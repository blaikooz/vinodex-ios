import Foundation

/// The settings that are read on the render path, memoised until one of them
/// changes (AUDIT **L16**).
///
/// Seven accessors across four files spelled the same idiom —
/// `UserDefaults.standard.string(forKey:)`, freshly, every time they were
/// asked. That is fine for something consulted on a button press; it is not
/// fine for `TextScale.current`, which `DexFont.resolvedSize` calls to build
/// **every `Font` in the app**, per glyph run, per render. The rest —
/// `UIScale`, `LcdMode`, `Sounds`, `Haptics` — copied the pattern from it, so
/// the cost spread rather than being contained.
///
/// The fix has to be a shared mechanism rather than a static `let` per
/// accessor, because these settings are live: the panel writes them and the
/// whole chassis is expected to repaint. A value cached forever would freeze
/// TEXT SIZE and LCD MODE at whatever they were on launch. So the cache is
/// invalidated wholesale by `UserDefaults.didChangeNotification`, which fires
/// synchronously on the writing thread for local changes — before SwiftUI gets
/// as far as re-rendering the views that `@AppStorage` just invalidated.
///
/// Only `UserDefaults.standard` is cached. The injected-defaults overloads
/// (`TextScale.current(in:)` and friends, which the tests use) read straight
/// through — one process-wide cache cannot serve several stores, and nothing
/// on a render path passes anything else.
///
/// Not an actor and not `@MainActor`: `TextScale.current` is a nonisolated
/// static, reachable from anywhere, and hopping isolation to read a cached
/// string would cost more than the read it replaces. A lock is the cheaper and
/// simpler guarantee.
public enum SettingsCache {
    private static let lock = NSLock()
    /// `String??` — the outer optional is "have we looked?", the inner is "was
    /// anything there?". Collapsing them would re-read on every miss, which is
    /// exactly the case `Haptics` cares about (its key is usually absent).
    nonisolated(unsafe) private static var strings: [String: String?] = [:]
    nonisolated(unsafe) private static var bools: [String: Bool?] = [:]

    /// Registers the invalidation observer exactly once, on first use. A
    /// `static let` rather than a flag: `swift_once` already does the
    /// thread-safe do-this-once part, and doing it lazily means a target that
    /// never reads a setting never registers anything.
    private static let observing: Bool = {
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: nil
        ) { _ in invalidate() }
        return true
    }()

    public static func string(forKey key: String) -> String? {
        _ = observing
        lock.lock()
        if let cached = strings[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        // Outside the lock: `UserDefaults` has its own synchronisation, and
        // holding ours across it would serialise every reader behind the first
        // miss. A concurrent duplicate read is harmless — the value is the same.
        let value = UserDefaults.standard.string(forKey: key)
        lock.lock()
        strings[key] = value
        lock.unlock()
        return value
    }

    /// The stored flag, or nil when the key has never been written — which is
    /// a meaningful third state here: `Haptics` defaults on and `Sounds`
    /// defaults off, so "absent" cannot be flattened to `false`.
    public static func bool(forKey key: String) -> Bool? {
        _ = observing
        lock.lock()
        if let cached = bools[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let defaults = UserDefaults.standard
        let value = defaults.object(forKey: key) == nil ? nil : defaults.bool(forKey: key)
        lock.lock()
        bools[key] = value
        lock.unlock()
        return value
    }

    /// Drops everything. Wholesale rather than per-key because
    /// `didChangeNotification` does not say which key moved, and the cache
    /// holds a handful of entries — refilling it costs the same handful of
    /// reads this type exists to make rare, not to make impossible.
    public static func invalidate() {
        lock.lock()
        strings.removeAll(keepingCapacity: true)
        bools.removeAll(keepingCapacity: true)
        lock.unlock()
    }
}
