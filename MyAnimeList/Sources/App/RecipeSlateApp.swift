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
                .tint(.orange)
        }
    }
}

private struct ContentView: View {
    @Environment(RecipeStore.self) private var store
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            Tab("Recipes", systemImage: "book", value: 0) {
                RecipeListView()
            }
            Tab("Cook", systemImage: "frying.pan", value: 1) {
                CookModeView()
            }
            Tab("Groceries", systemImage: "cart", value: 2) {
                ShoppingListView()
            }
            Tab("Search", systemImage: "magnifyingglass", value: 3, role: .search) {
                RecipeSearchView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
