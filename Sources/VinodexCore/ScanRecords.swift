import Foundation
import Observation

/// **A bottle the label reader actually met** (0.9.53, maintainer order).
///
/// The scanned *shelf* logs which catalog entries a scan matched; this is the
/// other half — a record of the real bottle: the producer line the OCR read,
/// the wine's name, the vintage, where it claimed to be from, and when it was
/// scanned. A wine journal of physical bottles, where the shelf is an index
/// into the encyclopedia.
///
/// Fields are snapshots, not references: the catalog regenerates and the
/// producer has no entity at all (see `LabelField.producer`), so the record
/// keeps the strings the label gave up. Only `matchedEntryIDs` points into
/// the catalog, and a stale id there drops harmlessly on resolve.
public struct ScanRecord: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    /// When the scan happened. A real date rather than a `dayIndex`: the
    /// journal renders it to the user, and reversing an index back into a
    /// calendar is a conversion nothing else needs.
    public let scannedAt: Date
    public let producer: String?
    public let wineName: String?
    public let vintage: String?
    public let region: String?
    public let country: String?
    /// The tastable entries the scan matched, in the reading's order.
    public let matchedEntryIDs: [String]

    public init(
        id: String = UUID().uuidString,
        scannedAt: Date = Date(),
        producer: String?,
        wineName: String?,
        vintage: String?,
        region: String?,
        country: String?,
        matchedEntryIDs: [String]
    ) {
        self.id = id
        self.scannedAt = scannedAt
        self.producer = producer
        self.wineName = wineName
        self.vintage = vintage
        self.region = region
        self.country = country
        self.matchedEntryIDs = matchedEntryIDs
    }

    /// What the journal card leads with. A label with no readable wine name
    /// still deserves a headline; the producer is the next-best identity and
    /// the fallback says honestly what this row is.
    public var displayName: String {
        wineName ?? producer ?? "SCANNED LABEL"
    }

    /// Build a record from a finished reading. Nil when the scan matched
    /// nothing worth journaling — a record with no fields and no matches
    /// would be a row that says only "something was photographed".
    public static func from(_ reading: LabelReading, at date: Date = Date()) -> ScanRecord? {
        let producer = reading.match(.producer)?.name
        let wineName = reading.match(.wineName)?.name
        let vintage = reading.match(.vintage)?.name
        let region = reading.match(.region)?.name ?? reading.match(.appellation)?.name
        let country = reading.match(.country)?.name
        let matched = reading.triedCandidateIDs
        guard producer != nil || wineName != nil || !matched.isEmpty else { return nil }
        return ScanRecord(
            scannedAt: date,
            producer: producer,
            wineName: wineName,
            vintage: vintage,
            region: region,
            country: country,
            matchedEntryIDs: matched
        )
    }
}

/// The journal itself: newest first, persisted as JSON in defaults (a few
/// hundred bytes a scan — proportionate, like the ratings map).
@MainActor
@Observable
public final class ScanRecordStore {
    public static let shared = ScanRecordStore()
    public static let storageKey = SavedDataKey.scanRecords.rawValue

    private let defaults: UserDefaults
    private(set) public var records: [ScanRecord]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        records = []
        reload()
    }

    /// Re-reads from defaults — the restore path, exactly as `BookmarkStore`
    /// documents it.
    public func reload() {
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([ScanRecord].self, from: data) {
            records = decoded
        } else {
            records = []
        }
    }

    /// Journal a finished reading. Returns the record it created, or nil when
    /// the reading was not worth a row.
    @discardableResult
    public func record(_ reading: LabelReading, at date: Date = Date()) -> ScanRecord? {
        guard let record = ScanRecord.from(reading, at: date) else { return nil }
        records.insert(record, at: 0)
        persist()
        return record
    }

    public func remove(id: String) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records.remove(at: index)
        persist()
    }

    public func reset() {
        records = []
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func persist() {
        if records.isEmpty {
            defaults.removeObject(forKey: Self.storageKey)
        } else if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
