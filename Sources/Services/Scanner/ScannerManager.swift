import Foundation
import GRDB

/// Manages scan source configurations and orchestrates scanning operations
@MainActor
final class ScannerManager: ObservableObject {
    @Published var scanSources: [ScanSource] = []
    @Published var isScanning = false
    @Published var lastScanResults: [String] = []

    private let database: DatabaseManager
    private let registry = ScannerRegistry.shared

    init(database: DatabaseManager) {
        self.database = database
        loadSources()
    }

    func loadSources() {
        do {
            scanSources = try database.read { db in
                try ScanSource.fetchAll(db)
            }
        } catch {
            print("Failed to load scan sources: \(error)")
        }
    }

    func addSource(_ source: ScanSource) throws {
        var newSource = source
        try database.write { db in
            try newSource.insert(db)
        }
        loadSources()
    }

    func updateSource(_ source: ScanSource) throws {
        try database.write { db in
            try source.update(db)
        }
        loadSources()
    }

    func deleteSource(_ source: ScanSource) throws {
        try database.write { db in
            try source.delete(db)
        }
        loadSources()
    }

    /// Run a scan for a specific source
    func runScan(for source: ScanSource) async throws {
        guard let scanner = registry.scanner(for: source.sourceType) else {
            throw ScanError.unsupportedSourceType(source.sourceType)
        }

        let config = try JSONDecoder().decode(
            ScannerConfig.self,
            from: (source.config).data(using: .utf8) ?? Data()
        )

        let formatter = ISO8601DateFormatter()
        let since = source.lastScannedAt.flatMap { formatter.date(from: $0) }

        isScanning = true
        defer { isScanning = false }

        let items = try await scanner.scan(config: config, since: since)

        var results: [String] = []
        for item in items {
            // Store raw activity log
            var log = ActivityLog(
                scanSourceId: source.id,
                sourceType: source.sourceType,
                entityType: .member, // Will be updated by processing
                entityId: 0,
                action: item.summary,
                rawData: item.rawJSON,
                occurredAt: formatter.string(from: item.occurredAt)
            )

            // Process through AI-enhanced pipeline
            let result = try await scanner.process(item: item, database: database)
            log.entityType = result.entityType
            log.entityId = result.entityId ?? 0
            log.processedData = try? String(
                data: JSONSerialization.data(
                    withJSONObject: result.changes,
                    options: .prettyPrinted
                ),
                encoding: .utf8
            )

            try database.write { db in
                try log.insert(db)
            }

            results.append("[\(result.entityType.rawValue)] \(result.action)")
        }

        // Update last scanned timestamp
        var updatedSource = source
        updatedSource.lastScannedAt = formatter.string(from: Date())
        updatedSource.lastError = nil
        try database.write { db in
            try updatedSource.update(db)
        }

        lastScanResults = results
        loadSources()
    }

    /// Run scans for all active sources
    func runAllScans() async {
        for source in scanSources where source.status == .active {
            do {
                try await runScan(for: source)
            } catch {
                print("Scan failed for \(source.name): \(error)")
                var updatedSource = source
                updatedSource.lastError = error.localizedDescription
                updatedSource.status = .error
                try? database.write { db in
                    try updatedSource.update(db)
                }
            }
        }
        loadSources()
    }
}

enum ScanError: LocalizedError {
    case unsupportedSourceType(ScanSourceType)
    case invalidConfig(String)
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSourceType(let type):
            return "Unsupported scanner type: \(type.rawValue)"
        case .invalidConfig(let msg):
            return "Invalid configuration: \(msg)"
        case .connectionFailed(let msg):
            return "Connection failed: \(msg)"
        }
    }
}
