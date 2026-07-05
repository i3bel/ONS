import SwiftUI
import UniformTypeIdentifiers

// MARK: - Search Tab (iOS 26 Native Style)

struct RecipeSearchView: View {
    @Environment(RecipeStore.self) private var store
    @State private var searchText = ""
    @State private var showFileImporter = false
    @State private var showFileExporter = false
    @State private var importMessage: ImportMessage?
    @State private var exportZipData: Data?
    @State private var showClearConfirm = false

    private enum ImportMessage: Equatable {
        case success(Int)
        case error(String)
    }

    private var isCommand: Bool { searchText.hasPrefix("/") }

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
                if searchText.isEmpty { emptyState }
                else if isCommand { commandView }
                else if results.isEmpty { noResultsState }
                else { searchResultsList }
            }
            .background(Color.pageBg)
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json, .zip], allowsMultipleSelection: false) {
                handleImport($0)
            }
            .fileExporter(isPresented: $showFileExporter, document: exportZipData.flatMap { ZipFileDocument(data: $0) }, contentType: .zip, defaultFilename: "RecipeSlate") { _ in }
        }
        .searchable(text: $searchText, placement: .automatic, prompt: "Search Recipes, Ingredients...")
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.textTertiary)
            Text("Search Recipes")
                .font(.title3.weight(.semibold))
            VStack(spacing: 4) {
                Text("/import  –  Import recipes from ZIP or JSON")
                Text("/export  –  Export all recipes as ZIP with images")
                Text("/clear   –  Delete all recipes and photos")
            }
            .font(.caption)
            .foregroundColor(.textSecondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsState: some View {
        ContentUnavailableView(
            "No Results",
            systemImage: "magnifyingglass",
            description: Text("Try a different search term.")
        )
    }

    // MARK: Search Results

    private var searchResultsList: some View {
        List {
            ForEach(results) { recipe in
                NavigationLink {
                    RecipeDetailView(recipe: recipe)
                } label: {
                    searchResultRow(recipe)
                }
                .listRowInsets(.init(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
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
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemFill))
                    Image(systemName: "fork.knife")
                        .font(.callout)
                        .foregroundColor(.textTertiary)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                    .foregroundColor(.textPrimary)
                Text("\(recipe.ingredients.count) ingredients · \(recipe.servings) servings")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(0)
    }

    // MARK: Commands

    private var commandView: some View {
        let cmd = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return VStack(spacing: Spacing.large) {
            switch cmd {
            case "/import": importCommandView
            case "/export": exportCommandView
            case "/clear": clearCommandView
            default: unknownCommandView
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

    // MARK: /import

    private var importCommandView: some View {
        VStack(spacing: Spacing.standard) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 44))
                .foregroundColor(.accentColor)
            Text("Import Recipes")
                .font(.title2.weight(.semibold))
            Text("Select a ZIP or JSON file containing one or more recipes to import.")
                .multilineTextAlignment(.center)
                .font(.callout)
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 40)

            Button(action: { showFileImporter = true }) {
                Label("Select File", systemImage: "doc.badge.plus")
            }
            .buttonStyle(PrimaryButton())
            .padding(.horizontal, 60)

            importResultMessage
        }
    }

    @ViewBuilder
    private var importResultMessage: some View {
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
            .font(.body.weight(.medium))
            .padding(Spacing.medium)
            .background(Color.tertiaryBg.opacity(0.5), in: RoundedRectangle(cornerRadius: CornerRadius.standard))
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                importMessage = .error("Cannot access file"); return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            // ZIP import
            if url.pathExtension.lowercased() == "zip" {
                if let count = store.importFromZip(url) {
                    importMessage = .success(count)
                } else {
                    importMessage = .error("Invalid ZIP file")
                }
                return
            }

            // JSON import
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()

                if let recipes = try? decoder.decode([ExportRecipe].self, from: data) {
                    for ex in recipes { store.add(ExportRecipe.toRecipe(ex)) }
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

    // MARK: /export

    private var exportCommandView: some View {
        VStack(spacing: Spacing.standard) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 44))
                .foregroundColor(.accentOrange)
            Text("Export Recipes")
                .font(.title2.weight(.semibold))
            Text("Export all \(store.recipes.count) recipes as a ZIP file with images.")
                .multilineTextAlignment(.center)
                .font(.callout)
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 40)

            Button(action: prepareExport) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(PrimaryButton(color: .accentOrange))
            .padding(.horizontal, 60)
        }
    }

    private func prepareExport() {
        guard let zipURL = store.exportAllToZip(),
              let data = try? Data(contentsOf: zipURL) else { return }
        exportZipData = data
        showFileExporter = true
    }

    // MARK: /clear

    private var clearCommandView: some View {
        VStack(spacing: Spacing.standard) {
            Image(systemName: "trash")
                .font(.system(size: 44))
                .foregroundColor(.accentRed)
            Text("Clear All Recipes")
                .font(.title2.weight(.semibold))
            Text("Delete all \(store.recipes.count) recipes and their photos.")
                .multilineTextAlignment(.center)
                .font(.callout)
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 40)

            Button(action: { showClearConfirm = true }) {
                Label("Clear Everything", systemImage: "trash")
            }
            .buttonStyle(PrimaryButton(color: .accentRed))
            .padding(.horizontal, 60)
        }
    }

    private var unknownCommandView: some View {
        VStack(spacing: 8) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 36))
                .foregroundColor(.textTertiary)
            Text("Unknown Command")
                .font(.title3.weight(.semibold))
            Text("Use /import or /export")
                .font(.callout)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - File Document

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

struct ZipFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip] }

    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

