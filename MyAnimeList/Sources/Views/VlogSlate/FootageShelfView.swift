import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct FootageShelfView: View {
    @EnvironmentObject var store: VlogSlateStore
    @State private var showExportSheet = false
    @State private var showImportPicker = false
    @State private var selected: FootageItem?
    @State private var filter: FootageFilter = .all
    @State private var searchText = ""

    private var filteredItems: [FootageItem] {
        let filtered: [FootageItem]
        switch filter {
        case .all:
            filtered = store.items
        case .good:
            filtered = store.items.filter { $0.status == .good }
        case .favorite:
            filtered = store.items.filter(\.isFavorite)
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return filtered }

        return filtered.filter { item in
            item.title.localizedCaseInsensitiveContains(query)
                || item.notes.localizedCaseInsensitiveContains(query)
                || item.timestamp.formatted(date: .numeric, time: .shortened).localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredItems.isEmpty {
                    ContentUnavailableView("没有镜头", systemImage: "rectangle.stack.badge.plus", description: Text("在 Slate 页拍板后，镜头会出现在这里。"))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(filteredItems) { item in
                        Button(action: { selected = item }) {
                            FootageRow(item: item)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(.init(top: 8, leading: 10, bottom: 8, trailing: 10))
                        .listRowSeparator(.visible)
                        .listRowSeparatorTint(.white.opacity(0.06))
                        .listRowBackground(Color.clear)
                        // swipe to delete removed — delete action moved into project actions menu
                    }
                }
            }
            .listStyle(.plain)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "搜索场次、备注或时间")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    VlogSlateNavigationTitleCapsule(count: filteredItems.count)
                }

                // moved count to the leading toolbar item; remove center title capsule

                ToolbarItem(placement: .topBarTrailing) {
                    projectActionsMenu
                }

                ToolbarItem(placement: .status) {
                    footageFilterMenu
                }
            }
            .sheet(item: $selected) { item in
                FootageDetailView(item: binding(for: item))
            }
            // Deletion now executes immediately from the menu; no confirmation dialog
            .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.vlogSlate, .json]) { result in
                importFootage(from: result)
            }
            .fileExporter(
                isPresented: $showExportSheet,
                document: exportDocument(),
                contentType: .vlogSlate,
                defaultFilename: "Project.vlogslate"
            ) { _ in }
        }
    }

    private var projectActionsMenu: some View {
            Menu {
            Button("删除所有镜头", systemImage: "trash", role: .destructive) {
                // Directly clear without additional confirmation per request
                store.clearAll()
            }

            Divider()

            Button("导入项目", systemImage: "square.and.arrow.down") {
                showImportPicker = true
            }

            Button("导出项目", systemImage: "square.and.arrow.up") {
                showExportSheet = true
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.title2)
                .frame(width: 20, height: 20)
                .padding(10)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Project actions")
    }

    private var footageFilterMenu: some View {
        Menu {
            Section("Filter") {
                Picker("Filter", selection: $filter) {
                    ForEach(FootageFilter.allCases) { filter in
                        Label(filter.title, systemImage: filter.systemImage).tag(filter)
                    }
                }
                .pickerStyle(.inline)
            }
        } label: {
            VlogSlateFilterSummaryCapsule(
                title: filter.title,
                count: filteredItems.count,
                systemImage: filter.systemImage
            )
        }
    }

    private func binding(for item: FootageItem) -> FootageItemBinding {
        FootageItemBinding(id: item.id)
    }

    private func delete(_ item: FootageItem) {
        store.items.removeAll { $0.id == item.id }
    }

    private func importFootage(from result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url) else { return }
        if let snapshot = try? JSONDecoder.vlogSlate.decode(VlogExportSnapshot.self, from: data) {
            store.replaceItems(snapshot.items, currentScene: snapshot.currentScene, currentTake: snapshot.currentTake)
        } else if let items = try? JSONDecoder.vlogSlate.decode([FootageItem].self, from: data) {
            store.replaceItems(items)
        }
    }

    private func exportDocument() -> VlogExportDocument {
        VlogExportDocument(items: store.items, currentScene: store.currentScene, currentTake: store.currentTake)
    }
}

struct FootageRow: View {
    var item: FootageItem

    private let rowHeight: CGFloat = 126
    private let posterWidth: CGFloat = 88
    private let posterHeight: CGFloat = 132

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            VlogSlatePosterBlock(scene: item.scene, take: item.take, style: .row)
                .frame(width: posterWidth, height: posterHeight)
                .padding(.vertical, -3)

            VStack(alignment: .leading, spacing: 0) {
                headerBlock

                Text(item.notes.isEmpty ? "No notes" : item.notes)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary.opacity(item.notes.isEmpty ? 0.62 : 0.82))
                    .multilineTextAlignment(.leading)
                    .truncationMode(.tail)
                    .lineLimit(2)
                    .padding(.top, 6)

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    VlogSlateStatusBadge(status: item.status)
                    if item.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.pink)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(.pink.opacity(0.1), in: Capsule(style: .continuous))
                    }
                }
                .padding(.top, 7)
            }
            .frame(maxWidth: .infinity, minHeight: rowHeight, maxHeight: rowHeight, alignment: .topLeading)
        }
        .frame(height: rowHeight, alignment: .top)
        .padding(.vertical, 5)
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(.headline.weight(.semibold))
                .lineLimit(1...2)
                .multilineTextAlignment(.leading)
                .truncationMode(.tail)

            HStack(spacing: 6) {
                Text(item.timestamp.formatted(date: .numeric, time: .shortened))
                Text("•")
                Text(item.id.prefix(8).uppercased())
                    .monospaced()
            }
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }
}

private enum FootageFilter: String, CaseIterable, Identifiable {
    case all, good, favorite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .good: return "完美"
        case .favorite: return "已收藏"
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "line.3.horizontal.decrease.circle"
        case .good: return "checkmark.circle.fill"
        case .favorite: return "heart.fill"
        }
    }
}

struct FootageItemBinding: Identifiable {
    let id: String
}

struct VlogExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.vlogSlate, .json] }
    var items: [FootageItem]
    var currentScene: Int
    var currentTake: Int

    init(items: [FootageItem], currentScene: Int, currentTake: Int) {
        self.items = items
        self.currentScene = currentScene
        self.currentTake = currentTake
    }

    init(configuration: ReadConfiguration) throws {
        items = []
        currentScene = 1
        currentTake = 1
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let snapshot = VlogExportSnapshot(items: items, currentScene: currentScene, currentTake: currentTake)
        let data = try JSONEncoder.vlogSlate.encode(snapshot)
        return .init(regularFileWithContents: data)
    }
}

private struct VlogExportSnapshot: Codable {
    var items: [FootageItem]
    var currentScene: Int
    var currentTake: Int
}

private extension UTType {
    static let vlogSlate = UTType(exportedAs: "com.openai.vlogslate")
}

private extension FootageItem {
    var title: String {
        "Scene \(scene) - Take \(take)"
    }
}
