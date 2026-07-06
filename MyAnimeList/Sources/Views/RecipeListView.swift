import SwiftUI

// MARK: - Recipe List (iOS 26 Native Style)

struct RecipeListView: View {
    @Environment(RecipeStore.self) private var store
    @Environment(CookingController.self) private var cooking
    @State private var showNewRecipe = false
    @State private var showDetail: Recipe?

    var body: some View {
        NavigationStack {
            Group {
                if store.recipes.isEmpty {
                    emptyState
                } else {
                    scrollContent
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showNewRecipe) {
                NavigationStack { RecipeEditView() }
            }
            .navigationDestination(item: $showDetail) { recipe in
                RecipeDetailView(recipe: recipe)
            }
        }
    }

    // MARK: List Content

    private var scrollContent: some View {
        List {
            ForEach(store.sortedRecipes) { recipe in
                RecipeRow(
                    recipe: recipe,
                    store: store
                ) {
                    showDetail = $0
                }
                .listRowInsets(.init(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        cooking.startCooking(steps: recipe.steps, recipeName: recipe.name)
                    } label: {
                        Label("Cook", systemImage: "play.fill")
                    }
                    .tint(.accentGreen)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        store.delete([recipe])
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }
        }
        .listStyle(.plain)
        .background(Color.pageBg)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            (Text("\(store.recipes.count)")
                .font(.title2.weight(.bold)).foregroundColor(.textPrimary)
            + Text(" Recipes")
                .font(.body.weight(.bold)).foregroundColor(.textSecondary)
            + Text("                                                     ")
                .foregroundColor(.clear))
                .contentTransition(.numericText())
                .animation(.spring, value: store.recipes.count)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: { showNewRecipe = true }) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
            }
        }
    }

    // MARK: Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Recipes",
            systemImage: "book.closed",
            description: Text("Tap + to add your first recipe.")
        )
    }
}

// MARK: - Recipe Row

private struct RecipeRow: View {
    var recipe: Recipe
    var store: RecipeStore
    var onTap: (Recipe) -> Void

    var body: some View {
        Button(action: { onTap(recipe) }) {
            HStack(spacing: 14) {
                thumbnail
                infoBlock
                chevron
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let url = store.photoURL(for: recipe), let img = UIImage(contentsOfFile: url.path) {
            Image(uiImage: img).resizable().scaledToFill()
                .frame(width: 90, height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        } else {
            RoundedRectangle(cornerRadius: 10)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                .foregroundColor(.textTertiary.opacity(0.4))
                .frame(width: 90, height: 130)
        }
    }

    private var infoBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recipe.name)
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .foregroundColor(.textPrimary)

            HStack(spacing: 4) {
                Text("\(recipe.servings) servings")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                if recipe.totalTime > 0 {
                    Text("·")
                        .font(.caption)
                        .foregroundColor(.textTertiary)
                    Text(timeStr(recipe.totalTime))
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }

            if !recipe.ingredients.isEmpty {
                Text(recipe.ingredients.map(\.name).joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
            }

            if !recipe.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(recipe.tags.prefix(3), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1), in: Capsule())
                    }
                    if recipe.tags.count > 3 {
                        Text("+\(recipe.tags.count - 3)")
                            .font(.caption2)
                            .foregroundColor(.textTertiary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundColor(.textTertiary)
    }

    private func timeStr(_ t: TimeInterval) -> String {
        let m = Int(t / 60)
        if m >= 60 { return "\(m/60)h \(m%60)m" }
        return "\(m)min"
    }
}
