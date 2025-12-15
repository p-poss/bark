import SwiftUI
import SwiftData

@main
struct BarkApp: App {
    let modelContainer: ModelContainer
    @StateObject private var appState = AppState()

    init() {
        do {
            modelContainer = try ModelContainer(for: TreeScan.self, AudioRecording.self)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .modelContainer(modelContainer)
        }
    }
}
