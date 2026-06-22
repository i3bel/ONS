import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Shared search logic

private func applySearchTokens(
    query: String,
    items: [FootageItem]
) -> [FootageItem] {
    let expandedQuery = query
        .replacingOccurrences(of: "(?i)([sct][><=]?\\d+(?:-\\d+)?)", with: " $1", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let tokens = expandedQuery.split { $0.isWhitespace }.map { String($0) }

    var requireGood = false
    var requireBackup = false
    var requireBad = false
    var requireFavorite = false
    var allowedScenes: Set<Int>? = nil
    var allowedClips: Set<Int>? = nil
    var allowedTakes: Set<Int>? = nil
    var textTokens: [String] = []

    for t in tokens {
        let lower = t.lowercased()
        if t.contains("完美") || lower.contains("good") { requireGood = true; continue }
        if t.contains("备用") || lower.contains("backup") { requireBackup = true; continue }
        if t.contains("废镜") || lower.contains("bad") { requireBad = true; continue }
        if t.contains("核心镜头") || t.contains("核心") || t.contains("已收藏") || t.contains("收藏") || lower.contains("favorite") { requireFavorite = true; continue }

        if let m = lower.first, (m == "s" || m == "c" || m == "t"), lower.count > 1 {
            let expr = String(lower.dropFirst())

            func addRangeToSet(_ lo: Int, _ hi: Int, into set: inout Set<Int>?) {
                var s = set ?? []
                for v in lo...hi { s.insert(v) }
                set = s
            }

            func targetSet(for m: Character) -> WritableKeyPath<(Set<Int>?, Set<Int>?, Set<Int>?), Set<Int>?> {
                switch m {
                case "s": return \.0
                case "c": return \.1
                default:  return \.2
                }
            }

            // Range: s1-3
            if expr.contains("-") {
                let parts = expr.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
                if parts.count == 2, let a = Int(parts[0]), let b = Int(parts[1]) {
                    let lo = min(a, b), hi = max(a, b)
                    if m == "s" { addRangeToSet(lo, hi, into: &allowedScenes); continue }
                    else if m == "c" { addRangeToSet(lo, hi, into: &allowedClips); continue }
                    else { addRangeToSet(lo, hi, into: &allowedTakes); continue }
                }
            }

            // Comparison: s>1, c>=2, t<3
            if expr.hasPrefix(">=") || expr.hasPrefix("<=") || expr.hasPrefix(">") || expr.hasPrefix("<") {
                var op = ""
                var numberPart = expr
                if expr.hasPrefix(">=") { op = ">="; numberPart = String(expr.dropFirst(2)) }
                else if expr.hasPrefix("<=") { op = "<="; numberPart = String(expr.dropFirst(2)) }
                else if expr.hasPrefix(">") { op = ">"; numberPart = String(expr.dropFirst(1)) }
                else if expr.hasPrefix("<") { op = "<"; numberPart = String(expr.dropFirst(1)) }

                if let n = Int(numberPart) {
                    let RANGE_MAX = 999
                    func applyOp(_ op: String, n: Int, into set: inout Set<Int>?) {
                        switch op {
                        case ">":
                            let lo = n + 1
                            if lo <= RANGE_MAX { addRangeToSet(lo, RANGE_MAX, into: &set) }
                        case ">=":
                            if n <= RANGE_MAX { addRangeToSet(n, RANGE_MAX, into: &set) }
                        case "<":
                            let hi = max(1, n - 1)
                            if hi >= 1 { addRangeToSet(1, hi, into: &set) }
                        case "<=":
                            let hi = max(1, n)
                            if hi >= 1 { addRangeToSet(1, hi, into: &set) }
                        default: break
                        }
                    }
                    if m == "s" { applyOp(op, n: n, into: &allowedScenes); continue }
                    else if m == "c" { applyOp(op, n: n, into: &allowedClips); continue }
                    else { applyOp(op, n: n, into: &allowedTakes); continue }
                }
            }

            // Exact: s1, c2, t3
            if let n = Int(expr) {
                if m == "s" { var s = allowedScenes ?? []; s.insert(n); allowedScenes = s; continue }
                if m == "c" { var s = allowedClips ?? []; s.insert(n); allowedClips = s; continue }
                if m == "t" { var s = allowedTakes ?? []; s.insert(n); allowedTakes = s; continue }
            }
        }
        textTokens.append(t)
    }

    return items.filter { item in
        if requireGood && item.status != .good { return false }
        if requireBackup && item.status != .backup { return false }
        if requireBad && item.status != .bad { return false }
        if requireFavorite && !item.isFavorite { return false }
        if let scenes = allowedScenes, !scenes.contains(item.scene) { return false }
        if let clips = allowedClips, !clips.contains(item.clip) { return false }
        if let takes = allowedTakes, !takes.contains(item.take) { return false }
        guard !textTokens.isEmpty else { return true }
        return textTokens.contains(where: { tok in
            item.title.localizedCaseInsensitiveContains(tok)
                || item.notes.localizedCaseInsensitiveContains(tok)
                || item.timestamp.formatted(date: .numeric, time: .shortened).localizedCaseInsensitiveContains(tok)
        })
    }
}

private func defaultSort(_ items: [FootageItem]) -> [FootageItem] {
    items.sorted { a, b in
        if (a.status == .good) != (b.status == .good) { return a.status == .good }
        if a.scene != b.scene { return a.scene > b.scene }
        if a.clip != b.clip { return a.clip > b.clip }
        return a.take > b.take
    }
}

// MARK: - FootageShelfView

struct FootageShelfView: View {
    @EnvironmentObject var store: VlogSlateStore
    @State private var showExportSheet = false
    @State private var showImportPicker = false
    @State private var selected: FootageItem?
    @State private var filter: FootageFilter = .all
    @State private var hideBad: Bool = true
    @State private var searchText = ""

    private var filteredItems: [FootageItem] {
        let filtered: [FootageItem]
        switch filter {
        case .all:     filtered = store.items
        case .good:    filtered = store.items.filter { $0.status == .good }
        case .backup:
            filtered = store.items.filter { $0.status == .backup }
        }

        let visibleItems = hideBad ? filtered.filter { $0.status != .bad } : filtered
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return defaultSort(visibleItems) }
        return defaultSort(applySearchTokens(query: query, items: visibleItems))
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
                    }
                }
            }
            .listStyle(.plain)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VlogSlateNavigationTitleCapsule(count: filteredItems.count)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    projectActionsMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    footageFilterMenu
                }
            }
            .sheet(item: $selected) { item in
                FootageDetailView(item: binding(for: item))
            }
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
            Section {
                Toggle(isOn: $hideBad) {
                    Label("隐藏废镜", systemImage: "eye.slash")
                }
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
            if shouldStopAccessing { url.stopAccessingSecurityScopedResource() }
        }
        guard let data = try? Data(contentsOf: url) else { return }
        if let snapshot = try? JSONDecoder.vlogSlate.decode(VlogExportSnapshot.self, from: data) {
            store.replaceItems(snapshot.items, currentScene: snapshot.currentScene)
        } else if let items = try? JSONDecoder.vlogSlate.decode([FootageItem].self, from: data) {
            store.replaceItems(items)
        }
    }

    private func exportDocument() -> VlogExportDocument {
        VlogExportDocument(items: store.items, currentScene: store.currentScene, currentTake: 1)
    }
}

// MARK: - FootageRow

struct FootageRow: View {
    @EnvironmentObject var store: VlogSlateStore
    var item: FootageItem

    private let rowHeight: CGFloat = 126
    private let posterWidth: CGFloat = 88
    private let posterHeight: CGFloat = 132

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            if let url = store.thumbnailURL(forScene: item.scene),
               let uiImage = UIImage(contentsOfFile: url.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: posterWidth, height: posterHeight)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: VlogSlatePosterBlock.Style.row.cornerRadius, style: .continuous))
                    .padding(.vertical, -3)
            } else {
                VlogSlatePosterBlock(scene: item.scene, take: item.take, style: .row)
                    .frame(width: posterWidth, height: posterHeight)
                    .padding(.vertical, -3)
            }

            VStack(alignment: .leading, spacing: 0) {
                headerBlock

                Text(item.notes.isEmpty ? "没有备注" : item.notes)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary.opacity(item.notes.isEmpty ? 0.62 : 0.82))
                    .multilineTextAlignment(.leading)
                    .truncationMode(.tail)
                    .lineLimit(2)
                    .padding(.top, 6)

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    VlogSlateStatusBadge(status: item.status)
                    Spacer()
                    Button {
                        if let idx = store.items.firstIndex(where: { $0.id == item.id }) {
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                store.items[idx].status = store.items[idx].status == .good ? .backup : .good
                            }
                        }
                    } label: {
                        Image(systemName: item.status == .good ? "heart.fill" : "heart")
                            .foregroundStyle(item.status == .good ? .pink.opacity(0.94) : .secondary.opacity(0.9))
                            .animation(.snappy(duration: 0.18), value: item.status)
                            .background {
                                Circle().fill(.white.opacity(item.status == .good ? 0.1 : 0.04))
                            }
                            .overlay {
                                Circle().stroke(.white.opacity(item.status == .good ? 0.18 : 0.08), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 7)
            }
            .frame(maxWidth: .infinity, minHeight: rowHeight, maxHeight: rowHeight, alignment: .topLeading)
        }
        .frame(height: rowHeight, alignment: .top)
        .padding(.vertical, 5)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                store.items.removeAll { $0.id == item.id }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func displayTitle(for item: FootageItem) -> String {
        let siblings = store.items.filter { $0.scene == item.scene && $0.clip == item.clip }
        if siblings.count > 1 {
            return "\(item.scene) 场 - \(item.clip) 镜 - \(item.take) 次"
        } else {
            return "\(item.scene) 场 - \(item.clip) 镜"
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(displayTitle(for: item))
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

// MARK: - FootageFilter

private enum FootageFilter: String, CaseIterable, Identifiable {
    case all, good, backup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:      return "全部"
        case .good:     return "完美"
        case .backup: return "备用"
        }
    }

    var systemImage: String {
        switch self {
        case .all:      return "line.3.horizontal.decrease.circle"
        case .good:     return "checkmark.circle.fill"
        case .backup: return "rectangle.stack.fill"
        }
    }
}

// MARK: - Supporting types

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

// 改后
private extension FootageItem {
    var title: String {
        "\(scene) 场 - \(clip) 镜 - \(take) 次"
    }
}

// MARK: - FootageSearchView

struct FootageSearchView: View {
    @EnvironmentObject var store: VlogSlateStore
    @State private var searchText = ""

    private var filteredItems: [FootageItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.items }
        return applySearchTokens(query: query, items: store.items)
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredItems.isEmpty {
                    ContentUnavailableView("没有结果", systemImage: "magnifyingglass", description: Text("没有找到匹配的镜头。"))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(filteredItems) { item in
                        FootageRow(item: item)
                            .listRowInsets(.init(top: 8, leading: 10, bottom: 8, trailing: 10))
                            .listRowSeparator(.visible)
                            .listRowSeparatorTint(.white.opacity(0.06))
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VlogSlateNavigationTitleCapsule(count: filteredItems.count)
                }
            }
            .searchable(text: $searchText, prompt: "搜索场次、备注或时间")
        }
    }
}
