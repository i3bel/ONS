import SwiftUI

struct RecipeListView: View {
    @Environment(RecipeStore.self) private var store
    @State private var search = ""
    @State private var showSort = false
    @State private var selectMode = false
    @State private var selected = Set<String>()
    @State private var showActionBar = false
    @State private var showNewRecipe = false
    @State private var showDetail: Recipe?

    private var filtered: [Recipe] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let sorted = store.sortedRecipes
        return q.isEmpty ? sorted : sorted.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                if filtered.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "book.closed").font(.system(size: 40)).foregroundStyle(.secondary.opacity(0.4))
                        Text("还没有食谱").font(.title3.weight(.semibold))
                        Text("点右上角 + 新建").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 60)
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                } else {
                    ForEach(filtered) { recipe in
                        RecipeRow(recipe: recipe, store: store, selectMode: selectMode, isSelected: selected.contains(recipe.id)) { tapped in
                            if selectMode {
                                if selected.contains(tapped.id) { selected.remove(tapped.id) }
                                else { selected.insert(tapped.id) }
                                showActionBar = !selected.isEmpty
                            } else {
                                showDetail = tapped
                            }
                        }
                        .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { store.delete(recipe) } label: { Label("删除", systemImage: "trash") }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("\(filtered.count) recipe")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "搜索食谱")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("\(filtered.count) recipe")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 2) {
                        sortButton
                        if !selectMode {
                            Button(action: { showNewRecipe = true }) {
                                Image(systemName: "plus").font(.title2.weight(.semibold)).frame(width: 20, height: 20).padding(10)
                            }
                            .buttonStyle(.glass).buttonBorderShape(.circle)
                        }
                        if selectMode {
                            Button("取消") { selectMode = false; selected.removeAll(); showActionBar = false }
                        } else {
                            Button(action: { selectMode = true; showActionBar = false }) {
                                Image(systemName: "ellipsis").font(.title2).frame(width: 20, height: 20).padding(10)
                            }
                            .buttonStyle(.glass).buttonBorderShape(.circle)
                        }
                    }
                }
            }
            .sheet(isPresented: $showNewRecipe) { RecipeEditView() }
            .sheet(item: $showDetail) { RecipeDetailView(recipe: $0) }
            .overlay(alignment: .bottom) {
                if showActionBar {
                    actionBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring, value: showActionBar)
        }
    }

    private var sortButton: some View {
        Menu {
            Picker("排序", selection: Binding(
                get: { store.sortOrder },
                set: { store.sortOrder = $0; store.save() }
            )) {
                Text("按名称").tag(RecipeStore.SortOrder.name)
                Text("按制作时间").tag(RecipeStore.SortOrder.prepTime)
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down").font(.caption).padding(8)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 24) {
            Button(role: .destructive) {
                let toDelete = store.recipes.filter { selected.contains($0.id) }
                store.delete(toDelete)
                selected.removeAll(); showActionBar = false; selectMode = false
            } label: {
                Label("删除 (\(selected.count))", systemImage: "trash")
            }
            Button("添加标签") {
                // Tag batch operation placeholder
                showActionBar = false; selectMode = false
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
        .padding(.bottom, 8)
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
                // Select circle
                if selectMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3).foregroundStyle(isSelected ? .orange : .secondary)
                }

                // Thumbnail
                ZStack {
                    if let url = store.photoURL(for: recipe), let img = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [.orange.opacity(0.3), .red.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Image(systemName: "fork.knife").font(.title2).foregroundStyle(.orange)
                    }
                }
                .frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 16))

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.name).font(.body.weight(.semibold)).lineLimit(1)
                    HStack(spacing: 6) {
                        Label("\(recipe.servings)人份", systemImage: "person.2").font(.caption)
                        if recipe.totalTime > 0 {
                            Label(timeStr(recipe.totalTime), systemImage: "clock").font(.caption)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Chevron (only in non-select mode)
                if !selectMode {
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
            }
            .padding(10)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private func timeStr(_ t: TimeInterval) -> String {
        let m = Int(t / 60)
        if m >= 60 { return "\(m/60)h \(m%60)m" }
        return "\(m)分钟"
    }
}
