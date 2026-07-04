import SwiftUI

struct RecipeListView: View {
    @Environment(RecipeStore.self) private var store
    @State private var showSortSheet = false
    @State private var selectMode = false
    @State private var selected = Set<String>()
    @State private var showActionBar = false
    @State private var showNewRecipe = false
    @State private var showDetail: Recipe?

    var body: some View {
        NavigationStack {
            List {
                if store.recipes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "book.closed").font(.system(size: 40)).foregroundColor(.textTertiary)
                        Text("No recipes yet").font(.title3.weight(.semibold))
                        Text("Tap + to add your first recipe").font(.calloutText).foregroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 60)
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                } else if selectMode {
                    selectAllRow
                    ForEach(store.sortedRecipes) { recipe in
                        RecipeRow(recipe: recipe, store: store, selectMode: true, isSelected: selected.contains(recipe.id)) {
                            if selected.contains($0.id) { selected.remove($0.id) }
                            else { selected.insert($0.id) }
                            showActionBar = !selected.isEmpty
                        }
                        .listRowInsets(.init(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                } else {
                    ForEach(store.sortedRecipes) { recipe in
                        RecipeRow(recipe: recipe, store: store, selectMode: false, isSelected: false) { showDetail = $0 }
                            .listRowInsets(.init(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button(action: {}) { Label("Make", systemImage: "play.fill") }.tint(.accentGreen)
                            }
                    }
                }
            }
            .listStyle(.plain)
            .background(Color.bgSecondary)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("\(store.recipes.count)").font(.title2.weight(.bold)).foregroundColor(.black)
                    + Text(" Recipes").font(.bodyText.weight(.bold)).foregroundColor(.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if selectMode {
                        Button("Cancel") { selectMode = false; selected.removeAll(); showActionBar = false }
                            .font(.bodyText).foregroundColor(.brandBlue)
                    } else {
                        HStack(spacing: 12) {
                            Button(action: { showSortSheet = true }) {
                                Image(systemName: "ellipsis").font(.title2).foregroundColor(.black)
                            }
                            Button(action: { showNewRecipe = true }) {
                                Image(systemName: "plus").font(.title2.weight(.semibold)).foregroundColor(.brandBlue)
                            }
                        }
                        .padding(.horizontal, 10)
                    }
                }
            }
            .confirmationDialog("", isPresented: $showSortSheet) {
                Button("Sort by Name") { store.sortOrder = .name; store.save() }
                Button("Sort by Cook Time") { store.sortOrder = .prepTime; store.save() }
                Button("Select Recipes") { selectMode = true }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showNewRecipe) { RecipeEditView() }
            .fullScreenCover(item: $showDetail) { r in NavigationStack { RecipeDetailView(recipe: r) } }
            .overlay(alignment: .bottom) {
                if showActionBar {
                    HStack(spacing: 20) {
                        Button(role: .destructive) {
                            let toDelete = store.recipes.filter { selected.contains($0.id) }
                            store.delete(toDelete); selected.removeAll(); showActionBar = false; selectMode = false
                        } label: { Label("Delete (\(selected.count))", systemImage: "trash") }
                        .font(.bodyText.weight(.semibold)).foregroundColor(.accentRed)
                        Button("Add Tags") {
                            showActionBar = false; selectMode = false
                        }.font(.bodyText.weight(.semibold)).foregroundColor(.brandBlue)
                    }
                    .padding(.horizontal, 24).padding(.vertical, 14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring, value: showActionBar)
        }
    }

    private var selectAllRow: some View {
        Button(action: {
            if selected.count == store.sortedRecipes.count { selected.removeAll() }
            else { selected = Set(store.sortedRecipes.map(\.id)) }
            showActionBar = !selected.isEmpty
        }) {
            HStack {
                Image(systemName: selected.count == store.sortedRecipes.count ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundColor(.brandBlue)
                Text(selected.count == store.sortedRecipes.count ? "Deselect All" : "Select All")
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

                ZStack {
                    if let url = store.photoURL(for: recipe), let img = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: [.brandBlue.opacity(0.2), .brandBlue.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Image(systemName: "fork.knife").font(.title2).foregroundColor(.brandBlue)
                    }
                }
                .frame(width: 100, height: 100).clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 6) {
                    Text(recipe.name).font(.bodyText.weight(.semibold)).lineLimit(1).foregroundColor(.black)

                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text("👥").font(.caption)
                            Text("\(recipe.servings)").font(.calloutText).foregroundColor(.textSecondary)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.bgSecondary).clipShape(Capsule())

                        if recipe.totalTime > 0 {
                            HStack(spacing: 4) {
                                Text("⏱").font(.caption)
                                Text(timeStr(recipe.totalTime)).font(.calloutText).foregroundColor(.textSecondary)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.bgSecondary).clipShape(Capsule())
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func timeStr(_ t: TimeInterval) -> String {
        let m = Int(t / 60)
        if m >= 60 { return "\(m/60)h \(m%60)m" }
        return "\(m)min"
    }
}
