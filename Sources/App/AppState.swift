import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var selectedSection: SidebarSection = .dashboard
    @Published var isLoading = false
    @Published var errorMessage: String?

    let database: DatabaseManager
    let scannerManager: ScannerManager
    let aiService: AIService

    init() {
        self.database = DatabaseManager.shared
        self.scannerManager = ScannerManager(database: DatabaseManager.shared)
        self.aiService = AIService(database: DatabaseManager.shared)
    }
}

enum SidebarSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case members = "Members"
    case projects = "Projects"
    case clients = "Clients"
    case skills = "Skills"
    case knowledge = "Knowledge"
    case aiInsights = "AI Insights"
    case scanners = "Scanners"
    case docAbout = "About"
    case docDataModel = "Data Model"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "rectangle.3.group"
        case .members: return "person.3"
        case .projects: return "folder"
        case .clients: return "building.2"
        case .skills: return "star"
        case .knowledge: return "book"
        case .aiInsights: return "brain"
        case .scanners: return "antenna.radiowaves.left.and.right"
        case .docAbout: return "info.circle"
        case .docDataModel: return "cylinder.split.1x2"
        }
    }
}
