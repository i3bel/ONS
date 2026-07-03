import SwiftUI

// MARK: - Shopping List (食材清单)

struct ShoppingListView: View {
    @Environment(RecipeStore.self) private var store
    @State private var showOnlyUnprepared = true
    @State private var searchText = ""

    private var groupedIngredients: [(IngredientCategory, [IngredientInfo])] {
        let allRecipes = store.recipes
        var infoList: [IngredientInfo] = []
        for recipe in allRecipes {
            for ingredient in recipe.ingredients {
                if showOnlyUnprepared && ingredient.isPrepared { continue }
                infoList.append(IngredientInfo(
                    id: ingredient.id,
                    name: ingredient.name,
                    amount: ingredient.amount,
                    unit: ingredient.unit,
                    category: ingredient.category,
                    isPrepared: ingredient.isPrepared,
                    recipeName: recipe.name,
                    recipeID: recipe.id
                ))
            }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            infoList = infoList.filter { $0.name.localizedCaseInsensitiveContains(query) }
        }

        let grouped = Dictionary(grouping: infoList, by: \.category)
        return grouped.map { ($0.key, $0.value) }
            .sorted { $0.0.rawValue.localizedCompare($1.0.rawValue) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                if store.recipes.isEmpty {
                    ContentUnavailableView(
                        "没有菜谱",
                        systemImage: "carrot",
                        description: Text("先在菜谱页添加菜谱和食材")
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else if groupedIngredients.isEmpty {
                    ContentUnavailableView(
                        showOnlyUnprepared ? "全部已准备" : "没有食材",
                        systemImage: "checkmark.circle",
                        description: Text(showOnlyUnprepared ? "所有食材都已准备就绪" : "还没有添加食材")
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(groupedIngredients, id: \.0) { category, items in
                        Section {
                            ForEach(items) { info in
                                IngredientRow(info: info, store: store)
                            }
                        } header: {
                            Label(category.rawValue, systemImage: category.systemImage)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("食材清单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Toggle(isOn: $showOnlyUnprepared) {
                        Image(systemName: showOnlyUnprepared ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .toggleStyle(.button)
                    .help("仅显示未准备")
                }
            }
            .searchable(text: $searchText, prompt: "搜索食材")
        }
    }
}

// MARK: - Ingredient Info

private struct IngredientInfo: Identifiable {
    var id: String
    var name: String
    var amount: Double
    var unit: String
    var category: IngredientCategory
    var isPrepared: Bool
    var recipeName: String
    var recipeID: String
}

// MARK: - Ingredient Row

private struct IngredientRow: View {
    var info: IngredientInfo
    var store: RecipeStore

    var body: some View {
        HStack(spacing: 10) {
            Button(action: togglePrepared) {
                Image(systemName: info.isPrepared ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(info.isPrepared ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(info.name)
                    .font(.subheadline.weight(.medium))
                    .strikethrough(info.isPrepared)
                    .foregroundStyle(info.isPrepared ? .secondary : .primary)
                HStack(spacing: 4) {
                    Text(info.displayAmount)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !info.isPrepared {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(info.recipeName)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
        .opacity(info.isPrepared ? 0.6 : 1)
    }

    private func togglePrepared() {
        guard let recipeIdx = store.recipes.firstIndex(where: { $0.id == info.recipeID }),
              let ingIdx = store.recipes[recipeIdx].ingredients.firstIndex(where: { $0.id == info.id })
        else { return }
        store.recipes[recipeIdx].ingredients[ingIdx].isPrepared.toggle()
        store.save()
    }
}

private extension IngredientInfo {
    var displayAmount: String {
        if amount == 0 { return "适量" }
        if amount == floor(amount) {
            return "\(Int(amount)) \(unit)"
        }
        return String(format: "%.1f %@", amount, unit)
    }
}
