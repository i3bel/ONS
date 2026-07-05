import SwiftUI

// MARK: - Recipe List (iOS 26 Native Style)

struct RecipeListView: View {
    @Environment(RecipeStore.self) private var store
    @Environment(CookingController.self) private var cooking
    @State private var selectMode = false
    @State private var selected = Set<String>()
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
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .toolbarRole(.editor)
            .sheet(isPresented: $showNewRecipe) { RecipeEditView() }
            .fullScreenCover(item: $showDetail) { r in
                NavigationStack { RecipeDetailView(recipe: r) }
            }
            .overlay(alignment: .bottom) { actionBarOverlay }
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: showDetail != nil)
        }
    }

    // MARK: Scroll Content

    private var scrollContent: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if selectMode { selectAllRow }

                ForEach(store.sortedRecipes) { recipe in
                    RecipeRow(
                        recipe: recipe,
                        store: store,
                        selectMode: selectMode,
                        isSelected: selected.contains(recipe.id)
                    ) {
                        if selectMode {
                            selected.formUnion([$0.id])
                        } else {
                            showDetail = $0
                        }
                    }
                    .contextMenu {
                        Button(action: {
                            cooking.startCooking(steps: recipe.steps, recipeName: recipe.name)
                        }) {
                            Label("Start Cooking", systemImage: "play.fill")
                        }
                        Button(action: { showDetail = recipe }) {
                            Label("View Recipe", systemImage: "book")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            cooking.startCooking(steps: recipe.steps, recipeName: recipe.name)
                        } label: {
                            Label("Cook", systemImage: "play.fill")
                        }
                        .tint(.accentGreen)
                    }
                }
            }
            .padding(.horizontal, Spacing.standard)
            .padding(.vertical, 8)
        }
        .background(Color.pageBg)
        .scrollIndicators(.hidden)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if selectMode {
                Button("Cancel") {
                    selectMode = false
                    selected.removeAll()
                }
                .font(.body.weight(.semibold))
            } else {
                HStack(spacing: 4) {
                    Button(action: { selectMode = true }) {
                        Image(systemName: "checkmark.circle")
                    }
                    Button(action: { showNewRecipe = true }) {
                        Image(systemName: "plus")
                    }
                }
                .font(.title3.weight(.semibold))
            }
        }
    }

    // MARK: Select All

    private var selectAllRow: some View {
        Button(action: {
            if selected.count == store.sortedRecipes.count {
                selected.removeAll()
            } else {
                selected = Set(store.sortedRecipes.map(\.id))
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: selected.count == store.sortedRecipes.count
                      ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(selected.count == store.sortedRecipes.count ? .accentColor : .textSecondary)
                Text(selected.count == store.sortedRecipes.count ? "Deselect All" : "Select All")
                    .font(.body.weight(.medium))
                    .foregroundColor(.accentColor)
                Spacer()
            }
            .padding(Spacing.standard)
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: CornerRadius.standard))
        }
        .buttonStyle(.plain)
    }

    // MARK: Action Bar

    @ViewBuilder
    private var actionBarOverlay: some View {
        if selectMode, !selected.isEmpty {
            HStack(spacing: 16) {
                Button(role: .destructive) {
                    let toDelete = store.recipes.filter { selected.contains($0.id) }
                    store.delete(toDelete)
                    selected.removeAll()
                    selectMode = false
                } label: {
                    Label("Delete (\(selected.count))", systemImage: "trash")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding(.horizontal, Spacing.large)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.standard + 4))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
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
    var selectMode: Bool
    var isSelected: Bool
    var onTap: (Recipe) -> Void

    var body: some View {
        Button(action: { onTap(recipe) }) {
            HStack(spacing: 14) {
                if selectMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(isSelected ? .accentColor : .textSecondary)
                }

                thumbnail
                infoBlock
                chevron
            }
            .padding(14)
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: CornerRadius.standard))
        }
        .buttonStyle(.plain)
    }

    private var thumbnail: some View {
        ZStack {
            if let url = store.photoURL(for: recipe), let img = UIImage(contentsOfFile: url.path) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(.systemFill))
                Image(systemName: "fork.knife")
                    .font(.title2)
                    .foregroundColor(.textTertiary)
            }
        }
        .frame(width: 90, height: 90)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var infoBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(recipe.name)
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .foregroundColor(.textPrimary)

            HStack(spacing: 8) {
                InfoPill(text: "\(recipe.servings) servings")
                if recipe.totalTime > 0 {
                    InfoPill(text: timeStr(recipe.totalTime))
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
