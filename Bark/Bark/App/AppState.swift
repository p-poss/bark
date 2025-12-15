import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: Tab = .scan
    @Published var isScanning: Bool = false
    @Published var currentTreeProfile: TreeProfile?
    @Published var audioEngineRunning: Bool = false

    enum Tab: Int, CaseIterable {
        case scan = 0
        case collection = 1
        case settings = 2

        var title: String {
            switch self {
            case .scan: return "Scan"
            case .collection: return "Collection"
            case .settings: return "Settings"
            }
        }

        var icon: String {
            switch self {
            case .scan: return "camera.viewfinder"
            case .collection: return "leaf.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }
}
