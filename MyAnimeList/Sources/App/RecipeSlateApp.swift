import SwiftUI

@main
struct RecipeSlateApp: App {
    @State private var store = RecipeStore()
    @State private var cooking = CookingController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(cooking)
        }
    }
}

private struct ContentView: View {
    @Environment(RecipeStore.self) private var store
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            Tab("食谱", systemImage: "book", value: 0) {
                RecipeListView()
            }
            Tab("烹饪", systemImage: "frying.pan", value: 1) {
                CookModeView()
            }
            Tab("采购", systemImage: "cart", value: 2) {
                ShoppingListView()
            }
            Tab("Search", systemImage: "magnifyingglass", value: 3, role: .search) {
                RecipeSearchView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
