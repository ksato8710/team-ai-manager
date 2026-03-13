import Foundation
import GRDB

// MARK: - Scanner Protocol
/// All scanners must conform to this protocol.
/// The architecture is plugin-based: each external source (Slack, GitHub, Figma, etc.)
/// implements this protocol to scan and convert raw data into the app's data models.
protocol ScannerProtocol {
    /// Unique identifier for this scanner type
    var sourceType: ScanSourceType { get }

    /// Human-readable name
    var displayName: String { get }

    /// Validate that the configuration is correct and the source is reachable
    func validate(config: ScannerConfig) async throws -> Bool

    /// Execute a scan and return raw activity items
    func scan(config: ScannerConfig, since: Date?) async throws -> [ScannedItem]

    /// Transform a scanned item into the appropriate data model updates
    func process(item: ScannedItem, database: DatabaseManager) async throws -> ProcessedResult
}

// MARK: - Scanner Config
/// Configuration for a scanner, loaded from ScanSource.config JSON
struct ScannerConfig: Codable {
    var apiKey: String?
    var apiUrl: String?
    var workspaceId: String?
    var channelIds: [String]?
    var repositoryNames: [String]?
    var teamId: String?
    var additionalParams: [String: String]?
}

// MARK: - Scanned Item
/// A single item retrieved from an external source before processing
struct ScannedItem {
    var sourceType: ScanSourceType
    var rawJSON: String
    var occurredAt: Date
    var externalId: String? // ID in the source system for dedup
    var summary: String? // Brief description for display
}

// MARK: - Processed Result
/// The result of processing a scanned item
struct ProcessedResult {
    var entityType: EntityType
    var entityId: Int64?
    var action: String
    var changes: [String: Any]

    /// Whether a new entity was created (vs updating existing)
    var isNewEntity: Bool
}

// MARK: - Scanner Registry
/// Central registry for all available scanners.
/// New scanners are registered here to be discoverable by the system.
@MainActor
final class ScannerRegistry {
    static let shared = ScannerRegistry()

    private var scanners: [ScanSourceType: any ScannerProtocol] = [:]

    private init() {
        // Register built-in scanners
        register(SlackScanner())
        register(GitHubScanner())
        register(ManualScanner())
    }

    func register(_ scanner: any ScannerProtocol) {
        scanners[scanner.sourceType] = scanner
    }

    func scanner(for type: ScanSourceType) -> (any ScannerProtocol)? {
        scanners[type]
    }

    var availableScanners: [ScanSourceType] {
        Array(scanners.keys).sorted { $0.rawValue < $1.rawValue }
    }
}
