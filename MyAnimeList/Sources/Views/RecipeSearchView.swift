import SwiftUI

// MARK: - Search Tab (iOS 26 system Search Tab with role: .search)

struct RecipeSearchView: View {
    @Environment(RecipeStore.self) private var store
    @State private var searchText = ""

    private var results: [Recipe] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return store.recipes.filter {
            $0.name.lowercased().contains(q) ||
            $0.ingredients.contains(where: { $0.name.lowercased().contains(q) }) ||
            $0.tags.contains { $0.lowercased().contains(q) }
        }
    }

    var body: some View {
        NavigationStack {
            if searchText.isEmpty {
                // Empty state when search hasn't been initiated
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").font(.system(size: 36)).foregroundColor(.textTertiary)
                    Text("Search Recipes").font(.title3.weight(.semibold))
                    Text("Find recipes by name, ingredients, or tags").font(.calloutText).foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.bgSecondary)
            } else if results.isEmpty {
                // No results
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.title2).foregroundColor(.textSecondary)
                    Text("No results").font(.bodyText).foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.bgSecondary)
            } else {
                // Search results
                List {
                    ForEach(results) { recipe in
                        NavigationLink {
                            RecipeDetailView(recipe: recipe)
                        } label: {
                            searchResultRow(recipe)
                        }
                        .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .background(Color.bgSecondary)
            }
        }
        .searchable(text: $searchText, placement: .automatic, prompt: "Recipes, Ingredients and More")
    }

    private func searchResultRow(_ recipe: Recipe) -> some View {
        HStack(spacing: 14) {
            ZStack {
                if let url = store.photoURL(for: recipe), let img = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(colors: [.brandBlue.opacity(0.2), .brandBlue.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "fork.knife").font(.callout).foregroundColor(.brandBlue)
                }
            }
            .frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name).font(.bodyText.weight(.semibold)).lineLimit(1).foregroundColor(.black)
                Text("\(recipe.ingredients.count) ingredients · \(recipe.servings) servings")
                    .font(.captionText).foregroundColor(.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(0)
        .background(Color.bgPrimary)
    }
}
