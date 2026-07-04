import SwiftUI
import UniformTypeIdentifiers

// MARK: - Search Tab (iOS 26 system Search Tab with role: .search)

struct RecipeSearchView: View {
    @Environment(RecipeStore.self) private var store
    @State private var searchText = ""
    @State private var showFileImporter = false
    @State private var showFileExporter = false
    @State private var importMessage: ImportMessage?
    @State private var exportDocument: RecipeFileDocument?
    @State private var showClearConfirm = false

    private enum ImportMessage: Equatable {
        case success(Int)
        case error(String)
    }

    private var isCommand: Bool {
        searchText.hasPrefix("/")
    }

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
            Group {
                if searchText.isEmpty {
                    emptyState
                } else if isCommand {
                    commandView
                } else if results.isEmpty {
                    noResultsState
                } else {
                    searchResultsList
                }
            }
            .background(Color.bgSecondary)
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                handleImport(result)
            }
            .fileExporter(isPresented: $showFileExporter, document: exportDocument, contentType: .json, defaultFilename: "recipes") { _ in }
        }
        .searchable(text: $searchText, placement: .automatic, prompt: "Recipes, Ingredients and More")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass").font(.system(size: 36)).foregroundColor(.textTertiary)
            Text("Search Recipes").font(.title3.weight(.semibold))
            Text("/import  –  Import recipes from a JSON file").font(.captionText).foregroundColor(.textSecondary)
            Text("/export  –  Export all recipes as JSON").font(.captionText).foregroundColor(.textSecondary)
            Text("/clear   –  Delete all recipes and photos").font(.captionText).foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - No Results

    private var noResultsState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.title2).foregroundColor(.textSecondary)
            Text("No results").font(.bodyText).foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Search Results

    private var searchResultsList: some View {
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

    // MARK: - Command View

    private var commandView: some View {
        let cmd = searchText.trimmingCharacters(in: .whitespaces).lowercased()

        return VStack(spacing: 20) {
            if cmd == "/import" {
                importCommandView
            } else if cmd == "/export" {
                exportCommandView
            } else if cmd == "/clear" {
                clearCommandView
            } else {
                unknownCommandView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog("Clear All Recipes?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear", role: .destructive) { store.clearAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all \(store.recipes.count) recipes and their photos. This cannot be undone.")
        }
    }

    // MARK: - /import

    private var importCommandView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.down").font(.system(size: 44)).foregroundColor(.brandBlue)
            Text("Import Recipes").font(.title2.weight(.semibold))
            Text("Select a JSON file containing one or more recipes to import.").multilineTextAlignment(.center)
                .font(.calloutText).foregroundColor(.textSecondary).padding(.horizontal, 40)

            Button(action: { showFileImporter = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.badge.plus").font(.title3)
                    Text("Select File")
                }
                .font(.bodyText.weight(.semibold)).foregroundColor(.white)
                .padding(.horizontal, 28).padding(.vertical, 12)
                .background(Color.brandBlue, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            // Import result message
            if let msg = importMessage {
                Group {
                    switch msg {
                    case .success(let count):
                        Label("Imported \(count) recipe\(count > 1 ? "s" : "")", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.accentGreen)
                    case .error(let text):
                        Label(text, systemImage: "xmark.circle.fill")
                            .foregroundColor(.accentRed)
                    }
                }
                .font(.bodyText.weight(.medium))
                .padding(12)
                .background(Color.pageBg.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                importMessage = .error("Cannot access file")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()

                // Try simplified export format first, fall back to full Recipe format
                if let recipes = try? decoder.decode([ExportRecipe].self, from: data) {
                    for ex in recipes {
                        store.add(ExportRecipe.toRecipe(ex))
                    }
                    importMessage = .success(recipes.count)
                } else if let recipes = try? decoder.decode([Recipe].self, from: data) {
                    for recipe in recipes { store.add(recipe) }
                    importMessage = .success(recipes.count)
                } else {
                    importMessage = .error("Invalid recipe file")
                }
            } catch {
                importMessage = .error("Invalid recipe file")
            }
        case .failure:
            break
        }
    }

    // MARK: - /export

    private var exportCommandView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.up").font(.system(size: 44)).foregroundColor(.accentOrange)
            Text("Export Recipes").font(.title2.weight(.semibold))
            Text("Export all \(store.recipes.count) recipes as a single JSON file.")
                .multilineTextAlignment(.center)
                .font(.calloutText).foregroundColor(.textSecondary).padding(.horizontal, 40)

            Button(action: prepareExport) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up").font(.title3)
                    Text("Export")
                }
                .font(.bodyText.weight(.semibold)).foregroundColor(.white)
                .padding(.horizontal, 28).padding(.vertical, 12)
                .background(Color.accentOrange, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private func prepareExport() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let exports = store.recipes.enumerated().map { i, recipe in
            ExportRecipe.from(recipe, order: i + 1)
        }
        if let data = try? encoder.encode(exports) {
            exportDocument = RecipeFileDocument(data: data)
            showFileExporter = true
        }
    }

    // MARK: - /clear

    private var clearCommandView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash").font(.system(size: 44)).foregroundColor(.accentRed)
            Text("Clear All Recipes").font(.title2.weight(.semibold))
            Text("Delete all \(store.recipes.count) recipes and their photos.")
                .multilineTextAlignment(.center)
                .font(.calloutText).foregroundColor(.textSecondary).padding(.horizontal, 40)

            Button(action: { showClearConfirm = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "trash").font(.title3)
                    Text("Clear Everything")
                }
                .font(.bodyText.weight(.semibold)).foregroundColor(.white)
                .padding(.horizontal, 28).padding(.vertical, 12)
                .background(Color.accentRed, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Unknown Command

    private var unknownCommandView: some View {
        VStack(spacing: 8) {
            Image(systemName: "questionmark.circle").font(.system(size: 36)).foregroundColor(.textTertiary)
            Text("Unknown command").font(.title3.weight(.semibold))
            Text("/import or /export").font(.calloutText).foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - File Document (for fileExporter)

struct RecipeFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Export / Import Recipe Format (human-friendly JSON)

/// Simplified recipe format — easy to hand-edit in a text editor.
/// No IDs, no timestamps, no photo data. Time uses human-readable strings like "10m", "1h 30m".
struct ExportRecipe: Codable {
    var order: Int
    var name: String
    var servings: Int
    var prep: String
    var cook: String
    var ingredients: [String]
    var steps: [String]
    var tags: [String]

    /// Convert a Recipe to the simplified export format.
    static func from(_ recipe: Recipe, order: Int) -> ExportRecipe {
        ExportRecipe(
            order: order,
            name: recipe.name,
            servings: recipe.servings,
            prep: timeString(recipe.prepTime),
            cook: timeString(recipe.cookTime),
            ingredients: recipe.ingredients.map { ing in
                "\(ing.amountWithUnit) \(ing.name)".trimmingCharacters(in: .whitespaces)
            },
            steps: recipe.steps.map(\.description),
            tags: recipe.tags
        )
    }

    /// Convert an ExportRecipe back to a full Recipe (import).
    static func toRecipe(_ ex: ExportRecipe) -> Recipe {
        Recipe(
            name: ex.name,
            servings: max(1, ex.servings),
            prepTime: parseTime(ex.prep),
            cookTime: parseTime(ex.cook),
            ingredients: ex.ingredients.map { Ingredient.parseChinese($0) },
            steps: ex.steps.enumerated().map { i, desc in
                CookingStep(order: i + 1, description: desc)
            },
            tags: ex.tags.filter { !$0.isEmpty }
        )
    }

    private static func timeString(_ interval: TimeInterval) -> String {
        let total = Int(interval); let h = total / 3600; let m = (total % 3600) / 60
        if h > 0, m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    private static func parseTime(_ s: String) -> TimeInterval {
        var total: Int = 0
        let str = s.trimmingCharacters(in: .whitespaces)
        // Match "Xh" hours
        if let r = str.range(of: #"(\d+)\s*h"#, options: .regularExpression) {
            let digits = str[r].filter { $0.isNumber }
            if let n = Int(digits) { total += n * 3600 }
        }
        // Match "Xm" minutes
        if let r = str.range(of: #"(\d+)\s*m"#, options: .regularExpression) {
            let digits = str[r].filter { $0.isNumber }
            if let n = Int(digits) { total += n * 60 }
        }
        return TimeInterval(total)
    }
}
