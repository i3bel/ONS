//
//  MyAnimeListApp.swift
//  MyAnimeList
//
//  Created by Samuel He on 2024/12/8.
//

import SwiftUI

// Minimal VlogSlate replacement app entry

@main
struct VlogSlateApp: App {
    @StateObject private var store = VlogSlateStore()

    var body: some Scene {
        WindowGroup {
            VlogSlateRootView()
                .environmentObject(store)
        }
    }
}

// Simple in-memory store and models
final class VlogSlateStore: ObservableObject {
    @Published var items: [FootageItem] = [] {
        didSet { save() }
    }
    @Published var currentScene: Int = 1 {
        didSet { save() }
    }
    @Published var currentTake: Int = 1 {
        didSet { save() }
    }
    @Published private(set) var currentSlateID: String = UUID().uuidString

    // Mapping from scene -> stored thumbnail filename
    @Published var sceneThumbnails: [Int: String] = [:]

    private let fileURL: URL
    private var isLoading = false

    init() {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = supportDirectory.appendingPathComponent("VlogSlate", isDirectory: true)
        fileURL = directory.appendingPathComponent("footage.json")
        load()
    }

    func addCurrentTake() {
        let item = FootageItem(id: currentSlateID, scene: currentScene, clip: 1, take: currentTake, timestamp: Date(), notes: "", status: .backup, isFavorite: false)
        items.insert(item, at: 0)
        currentTake += 1
        currentSlateID = UUID().uuidString
        save()
    }

    func clearAll() {
        items.removeAll()
        currentScene = 1
        currentTake = 1
        currentSlateID = UUID().uuidString
        save()
    }

    func replaceItems(_ importedItems: [FootageItem], currentScene importedScene: Int? = nil, currentTake importedTake: Int? = nil) {
        items = importedItems.sorted { $0.timestamp > $1.timestamp }
        if let importedScene, let importedTake {
            currentScene = importedScene
            currentTake = importedTake
        } else if let latest = items.max(by: { lhs, rhs in
            lhs.scene == rhs.scene ? lhs.take < rhs.take : lhs.scene < rhs.scene
        }) {
            currentScene = latest.scene
            currentTake = latest.take + 1
        } else {
            currentScene = 1
            currentTake = 1
        }
        currentSlateID = UUID().uuidString
        save()
    }

    func thumbnailURL(forScene scene: Int) -> URL? {
        guard let filename = sceneThumbnails[scene] else { return nil }
        return fileURL.deletingLastPathComponent().appendingPathComponent(filename)
    }

    func payloadForCurrentSlate() -> VlogSlatePayload {
        VlogSlatePayload(id: currentSlateID, scene: currentScene, take: currentTake)
    }

    private func load() {
        isLoading = true
        defer { isLoading = false }

        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder.vlogSlate.decode(VlogSlateSnapshot.self, from: data)
        else { return }

        items = snapshot.items
        currentScene = snapshot.currentScene
        currentTake = snapshot.currentTake
        currentSlateID = snapshot.currentSlateID
        sceneThumbnails = snapshot.sceneThumbnails ?? [:]
    }

    private func save() {
        guard !isLoading else { return }

        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let snapshot = VlogSlateSnapshot(items: items, currentScene: currentScene, currentTake: currentTake, currentSlateID: currentSlateID, sceneThumbnails: sceneThumbnails)
            let data = try JSONEncoder.vlogSlate.encode(snapshot)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save VlogSlate data: \(error)")
        }
    }
}

struct FootageItem: Identifiable, Codable {
    enum Status: String, Codable {
        case good, bad, backup
    }
    var id: String
    var scene: Int
    var clip: Int
    var take: Int
    var timestamp: Date
    var notes: String
    var status: Status
    var isFavorite: Bool

    // 兼容旧数据：旧 JSON 没有 clip 字段时默认为 1
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        scene = try container.decode(Int.self, forKey: .scene)
        clip = try container.decodeIfPresent(Int.self, forKey: .clip) ?? 1
        take = try container.decode(Int.self, forKey: .take)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        notes = try container.decode(String.self, forKey: .notes)
        status = try container.decode(Status.self, forKey: .status)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
    }

    init(id: String, scene: Int, clip: Int, take: Int, timestamp: Date, notes: String, status: Status, isFavorite: Bool) {
        self.id = id
        self.scene = scene
        self.clip = clip
        self.take = take
        self.timestamp = timestamp
        self.notes = notes
        self.status = status
        self.isFavorite = isFavorite
    }
}

struct VlogSlatePayload: Codable {
    var id: String
    var scene: Int
    var take: Int

    var visibleLabel: String {
        "S\(scene) T\(take)"
    }

    var qrString: String {
        guard let data = try? JSONEncoder.vlogSlate.encode(self),
              let string = String(data: data, encoding: .utf8)
        else { return visibleLabel }

        return string
    }
}

private struct VlogSlateSnapshot: Codable {
    var items: [FootageItem]
    var currentScene: Int
    var currentTake: Int
    var currentSlateID: String
    var sceneThumbnails: [Int: String]?
}

extension JSONEncoder {
    static var vlogSlate: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var vlogSlate: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

// Root view with tabbed interface: Shelf and Slate
struct VlogSlateRootView: View {
    @EnvironmentObject var store: VlogSlateStore
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Shelf", systemImage: "list.bullet", value: 0) {
                FootageShelfView()
            }
            Tab("Slate", systemImage: "viewfinder", value: 1) {
                SlateControllerView()
            }
            Tab("Scanner", systemImage: "qrcode.viewfinder", value: 2) {
                ScannerView()
            }
            Tab(value: 3, role: .search) {
                FootageSearchView()
            }
        }
    }
}
