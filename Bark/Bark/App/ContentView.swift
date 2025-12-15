import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ScannerView()
                .tabItem {
                    Label(AppState.Tab.scan.title, systemImage: AppState.Tab.scan.icon)
                }
                .tag(AppState.Tab.scan)

            CollectionView()
                .tabItem {
                    Label(AppState.Tab.collection.title, systemImage: AppState.Tab.collection.icon)
                }
                .tag(AppState.Tab.collection)

            SettingsView()
                .tabItem {
                    Label(AppState.Tab.settings.title, systemImage: AppState.Tab.settings.icon)
                }
                .tag(AppState.Tab.settings)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
