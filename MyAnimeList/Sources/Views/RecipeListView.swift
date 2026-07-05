import SwiftUI

struct RecipeListView: View {
    @Environment(RecipeStore.self) private var store
    @Environment(CookingController.self) private var cooking
    @State private var selectMode = false
    @State private var selected = Set<String>()
    @State private var showActionBar = false
    @State private var showNewRecipe = false
    @State private var showDetail: Recipe?

    var body: some View {
        NavigationStack {
            Group {
                if store.recipes.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showNewRecipe) { RecipeEditView() }
            .fullScreenCover(item: $showDetail) { r in
                NavigationStack { RecipeDetailView(recipe: r) }
            }
            .overlay(alignment: .bottom) { actionBarOverlay }
            .animation(.spring, value: showActionBar)
        }
    }

    // MARK: List

    private var listContent: some View {
        List {
            if selectMode { selectAllRow }
            let recipes = selectMode ? store.sortedRecipes : store.sortedRecipes
            ForEach(recipes) { recipe in
                RecipeRow(
                    recipe: recipe,
                    store: store,
                    selectMode: selectMode,
                    isSelected: selected.contains(recipe.id)
                ) {
                    if selectMode {
                        selected.formUnion([$0.id])
                        showActionBar = !selected.isEmpty
                    } else {
                        showDetail = $0
                    }
                }
                .listRowInsets(.init(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        cooking.startCooking(steps: recipe.steps, recipeName: recipe.name)
                    } label: {
                        Label("Make", systemImage: "play.fill")
                    }
                    .tint(.accentGreen)
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
            Text("\(store.recipes.count)").font(.title2.weight(.bold)).foregroundColor(.textPrimary)
            + Text(" Recipes").font(.bodyText.weight(.bold)).foregroundColor(.textSecondary)
        }
        ToolbarItem(placement: .topBarTrailing) {
            if selectMode {
                Button("Cancel") {
                    selectMode = false
                    selected.removeAll()
                    showActionBar = false
                }
                .font(.bodyText).foregroundColor(.brandBlue)
            } else {
                Button(action: { showNewRecipe = true }) {
                    Image(systemName: "plus").font(.title2.weight(.semibold)).foregroundColor(.brandBlue)
                }
            }
        }
    }

    // MARK: Action Bar

    private var actionBarOverlay: some View {
        Group {
            if showActionBar {
                HStack(spacing: 20) {
                    Button(role: .destructive) {
                        let toDelete = store.recipes.filter { selected.contains($0.id) }
                        store.delete(toDelete)
                        selected.removeAll()
                        showActionBar = false
                        selectMode = false
                    } label: {
                        Label("Delete (\(selected.count))", systemImage: "trash")
                    }
                    .font(.bodyText.weight(.semibold)).foregroundColor(.accentRed)
                }
                .padding(.horizontal, 24).padding(.vertical, 14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed").font(.system(size: 40)).foregroundColor(.textTertiary)
            Text("还没有菜谱").font(.title3.weight(.semibold))
            Text("点击 + 添加你的第一个菜谱").font(.calloutText).foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var selectAllRow: some View {
        Button(action: {
            if selected.count == store.sortedRecipes.count { selected.removeAll() }
            else { selected = Set(store.sortedRecipes.map(\.id)) }
            showActionBar = !selected.isEmpty
        }) {
            HStack {
                Image(systemName: selected.count == store.sortedRecipes.count
                      ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundColor(.brandBlue)
                Text(selected.count == store.sortedRecipes.count
                     ? "Deselect All" : "Select All")
                    .font(.bodyText).foregroundColor(.brandBlue)
            }
        }
        .listRowInsets(.init(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
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
                        .font(.title3).foregroundColor(isSelected ? .brandBlue : .textSecondary)
                }

                thumbnail
                infoBlock
            }
            .padding(14)
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var thumbnail: some View {
        ZStack {
            if let url = store.photoURL(for: recipe), let img = UIImage(contentsOfFile: url.path) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [.brandBlue.opacity(0.2), .brandBlue.opacity(0.1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "fork.knife").font(.title2).foregroundColor(.brandBlue)
            }
        }
        .frame(width: 100, height: 100).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var infoBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(recipe.name).font(.bodyText.weight(.semibold)).lineLimit(1).foregroundColor(.textPrimary)

            HStack(spacing: 8) {
                Label("👥", systemImage: "")
                    .labelStyle(.iconOnly)
                    .font(.caption)
                Text("\(recipe.servings)").font(.calloutText).foregroundColor(.textSecondary)
                    .labeledWithPill(bg: Color.pageBg)

                if recipe.totalTime > 0 {
                    Text(timeStr(recipe.totalTime))
                        .font(.calloutText).foregroundColor(.textSecondary)
                        .labeledWithPill(bg: Color.pageBg)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timeStr(_ t: TimeInterval) -> String {
        let m = Int(t / 60)
        if m >= 60 { return "\(m/60)h \(m%60)m" }
        return "\(m)min"
    }
}

// MARK: - Pill Label Modifier

private extension View {
    func labeledWithPill(bg: Color) -> some View {
        HStack(spacing: 4) {
            self
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(bg).clipShape(Capsule())
    }
}
