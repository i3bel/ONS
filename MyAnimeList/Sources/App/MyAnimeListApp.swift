import SwiftUI
import Observation

@main
struct RecipeSlateApp: App {
    @State private var recipeStore = RecipeStore()

    var body: some Scene {
        WindowGroup {
            RecipeSlateTabView()
                .environment(recipeStore)
        }
    }
}

// MARK: - Root TabView

struct RecipeSlateTabView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("菜谱", systemImage: "book", value: 0) {
                RecipeShelfView()
            }
            Tab("烹饪", systemImage: "frying.pan", value: 1) {
                CookModeView()
            }
            Tab("食材", systemImage: "carrot", value: 2) {
                ShoppingListView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

// MARK: - Navigation Title (Crouton style)

struct SlateNavigationTitle: View {
    var count: Int
    var title: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(count)))
        }
        .animation(.bouncy, value: count)
    }
}
