import SwiftUI
import UniformTypeIdentifiers

// MARK: - RecipeShelfView

struct RecipeShelfView: View {
    @Environment(RecipeStore.self) private var store
    var toggleMode: (() -> Void)?
    @State private var showNewRecipe = false
    @State private var selectedRecipe: Recipe?
    @State private var filter: RecipeFilter = .all
    @State private var searchText = ""
    @State private var showExportSheet = false
    @State private var showImportPicker = false

    private var filteredRecipes: [Recipe] {
        var result = store.recipes
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter { recipe in
                recipe.name.localizedCaseInsensitiveContains(query)
                    || recipe.ingredients.contains(where: { $0.name.localizedCaseInsensitiveContains(query) })
                    || recipe.notes.localizedCaseInsensitiveContains(query)
            }
        }
        switch filter {
        case .all: break
        case .wantToEat: result = result.filter { $0.status == .wantToEat }
        case .favorite: result = result.filter { $0.status == .favorite }
        case .worst: result = result.filter { $0.status == .worst }
        }
        return result.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredRecipes.isEmpty {
                    ContentUnavailableView(
                        "没有菜谱",
                        systemImage: "book",
                        description: Text("点击右上角 + 添加第一个菜谱")
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(filteredRecipes) { recipe in
                        Button(action: { selectedRecipe = recipe }) {
                            RecipeRow(recipe: recipe, store: store)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(.init(top: 8, leading: 10, bottom: 8, trailing: 10))
                        .listRowSeparator(.visible)
                        .listRowSeparatorTint(.white.opacity(0.06))
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.deleteRecipe(recipe)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    RecipeNavigationTitleCapsule(count: filteredRecipes.count, onLongPress: toggleMode)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        filterMenu
                        addMenu
                    }
                }
            }
            .sheet(item: $selectedRecipe) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .sheet(isPresented: $showNewRecipe) {
                RecipeDetailView(recipe: nil)
            }
            .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.json]) { result in
                importRecipes(from: result)
            }
            .fileExporter(
                isPresented: $showExportSheet,
                document: exportDocument(),
                contentType: .json,
                defaultFilename: "Recipes.json"
            ) { _ in }
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Filter", selection: $filter) {
                ForEach(RecipeFilter.allCases) { f in
                    Label(f.title, systemImage: f.systemImage).tag(f)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: filter.systemImage)
                .font(.title2)
                .frame(width: 20, height: 20)
                .padding(10)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
    }

    private var addMenu: some View {
        Menu {
            Button("新建菜谱", systemImage: "plus") {
                showNewRecipe = true
            }
            Divider()
            Button("导入", systemImage: "square.and.arrow.down") {
                showImportPicker = true
            }
            Button("导出", systemImage: "square.and.arrow.up") {
                showExportSheet = true
            }
            if !store.recipes.isEmpty {
                Divider()
                Button("清空所有菜谱", systemImage: "trash", role: .destructive) {
                    store.recipes.removeAll()
                    store.save()
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.title2)
                .frame(width: 20, height: 20)
                .padding(10)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
    }

    private func importRecipes(from result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let shouldStop = url.startAccessingSecurityScopedResource()
        defer { if shouldStop { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let imported = try? JSONDecoder.recipeStore.decode([Recipe].self, from: data)
        else { return }
        for recipe in imported {
            store.addRecipe(recipe)
        }
    }

    private func exportDocument() -> RecipeExportDocument {
        RecipeExportDocument(recipes: filteredRecipes)
    }
}

// MARK: - Recipe Row

private struct RecipeRow: View {
    var recipe: Recipe
    var store: RecipeStore

    var body: some View {
        HStack(spacing: 11) {
            // Thumbnail
            Group {
                if let url = store.thumbnailURL(for: recipe),
                   let uiImage = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [.orange.opacity(0.3), .red.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: "fork.knife")
                            .font(.title2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .frame(width: 72, height: 72)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.headline.weight(.semibold))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    RecipeStatusBadge(status: recipe.status)
                    if recipe.totalTime > 0 {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(timeDisplay(recipe.totalTime))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                if !recipe.ingredients.isEmpty {
                    Text("\(recipe.ingredients.count) 种食材 · \(recipe.steps.count) 步")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private func timeDisplay(_ interval: TimeInterval) -> String {
        let total = Int(interval / 60)
        if total >= 60 {
            return "\(total / 60)h \(total % 60)m"
        }
        return "\(total)m"
    }
}

// MARK: - Recipe Status Badge

struct RecipeStatusBadge: View {
    var status: RecipeStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.systemImage)
                .font(.caption2)
            Text(status.rawValue)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(status.tintColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background {
            Capsule().fill(status.tintColor.opacity(0.12))
        }
    }
}

private extension RecipeStatus {
    var tintColor: Color {
        switch self {
        case .wantToEat: return .orange
        case .neutral: return .gray
        case .favorite: return .pink
        case .worst: return .red
        }
    }
}

// MARK: - Filter

private enum RecipeFilter: String, CaseIterable, Identifiable {
    case all, wantToEat, favorite, worst
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "全部"
        case .wantToEat: return "想吃"
        case .favorite: return "最爱吃"
        case .worst: return "最难吃"
        }
    }
    var systemImage: String {
        switch self {
        case .all: return "line.3.horizontal.decrease.circle"
        case .wantToEat: return "heart"
        case .favorite: return "heart.fill"
        case .worst: return "hand.thumbsdown"
        }
    }
}

// MARK: - Export

private struct RecipeExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var recipes: [Recipe]

    init(recipes: [Recipe]) {
        self.recipes = recipes
    }

    init(configuration: ReadConfiguration) throws {
        recipes = []
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder.recipeStore.encode(recipes)
        return .init(regularFileWithContents: data)
    }
}
