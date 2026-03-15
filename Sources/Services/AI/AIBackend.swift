import Foundation

/// Supported AI CLI backends
enum AIBackend: String, CaseIterable, Identifiable {
    case claude = "claude"
    case codex = "codex"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "OpenAI Codex CLI"
        }
    }

    var cliCommand: String { rawValue }

    /// Well-known install paths for each CLI
    var searchPaths: [String] {
        let home = NSHomeDirectory()
        switch self {
        case .claude:
            return [
                "\(home)/.local/bin/claude",
                "/usr/local/bin/claude",
                "\(home)/.claude/local/claude",
            ]
        case .codex:
            return [
                "\(home)/.local/bin/codex",
                "/usr/local/bin/codex",
                "\(home)/.npm-global/bin/codex",
                "/opt/homebrew/bin/codex",
            ]
        }
    }

    // MARK: - Current selection (persisted via UserDefaults)

    private static let key = "aiBackend"

    static var current: AIBackend {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key),
                  let backend = AIBackend(rawValue: raw) else {
                return .claude
            }
            return backend
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }
}

// MARK: - CLI Resolver

enum CLIResolver {

    /// Resolve the executable path for the given backend.
    /// Returns nil if the CLI cannot be found.
    static func resolve(_ backend: AIBackend) -> String? {
        // 1. Check well-known paths
        for path in backend.searchPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // 2. Fallback: `which` lookup via PATH
        return whichLookup(backend.cliCommand)
    }

    /// Check whether the given backend CLI is available on this machine.
    static func isAvailable(_ backend: AIBackend) -> Bool {
        resolve(backend) != nil
    }

    // MARK: - Private

    private static func whichLookup(_ command: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", command]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let result = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return result.isEmpty ? nil : result
    }
}
