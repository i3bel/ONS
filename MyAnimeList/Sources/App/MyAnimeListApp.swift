import SwiftUI
import Observation

@main
struct VlogSlateApp: App {
    @State private var store = VlogSlateStore()

    var body: some Scene {
        WindowGroup {
            VlogSlateRootView()
                .environment(store)
        }
    }
}

// MARK: - Root View

struct VlogSlateRootView: View {
    @Environment(VlogSlateStore.self) private var store
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("片库", systemImage: "list.bullet", value: 0) {
                FootageShelfView()
            }
            Tab("场记", systemImage: "viewfinder", value: 1) {
                SlateControllerView()
            }
            Tab("扫码", systemImage: "qrcode.viewfinder", value: 2) {
                ScannerView()
            }
            Tab(value: 3, role: .search) {
                FootageSearchView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
