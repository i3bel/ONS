import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Store

@Observable
final class VlogSlateStore {
    var items: [FootageItem] = [] {
        didSet { save() }
    }
    var currentScene: Int = 1 {
        didSet {
            currentClip = 1
            save()
        }
    }
    var currentClip: Int = 1 {
        didSet { save() }
    }
    private(set) var currentSlateID: String = UUID().uuidString

    /// Mapping from scene -> stored thumbnail filename
    var sceneThumbnails: [Int: String] = [:]

    private let fileURL: URL
    private var isLoading = false

    init() {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = supportDirectory.appendingPathComponent("VlogSlate", isDirectory: true)
        fileURL = directory.appendingPathComponent("footage.json")
        load()
    }

    func refreshSlateID() {
        currentSlateID = UUID().uuidString
    }

    func addCurrentTake() {
        let existingTakes = items.filter { $0.scene == currentScene && $0.clip == currentClip }.count
        let newTake = existingTakes + 1
        let item = FootageItem(
            id: currentSlateID,
            scene: currentScene,
            clip: currentClip,
            take: newTake,
            timestamp: Date(),
            notes: "",
            status: .backup,
            isFavorite: false
        )
        items.insert(item, at: 0)
        refreshSlateID()
        save()
    }

    func clearAll() {
        items.removeAll()
        currentScene = 1
        currentClip = 1
        refreshSlateID()
        for filename in sceneThumbnails.values {
            let url = fileURL.deletingLastPathComponent().appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: url)
        }
        sceneThumbnails.removeAll()
        save()
    }

    func replaceItems(_ importedItems: [FootageItem], currentScene importedScene: Int? = nil) {
        items = importedItems.sorted { $0.timestamp > $1.timestamp }
        if let importedScene {
            currentScene = importedScene
            currentClip = 1
        } else if let latest = items.max(by: { lhs, rhs in
            lhs.scene == rhs.scene ? lhs.clip < rhs.clip : lhs.scene < rhs.scene
        }) {
            currentScene = latest.scene
            currentClip = latest.clip
        } else {
            currentScene = 1
            currentClip = 1
        }
        refreshSlateID()
        save()
    }

    func thumbnailURL(forScene scene: Int) -> URL? {
        guard let filename = sceneThumbnails[scene] else { return nil }
        return fileURL.deletingLastPathComponent().appendingPathComponent(filename)
    }

    func payloadForCurrentSlate() -> VlogSlatePayload {
        let existingTakes = items.filter { $0.scene == currentScene && $0.clip == currentClip }.count
        return VlogSlatePayload(id: currentSlateID, scene: currentScene, clip: currentClip, take: existingTakes + 1)
    }

    private func load() {
        isLoading = true
        defer { isLoading = false }

        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder.vlogSlate.decode(VlogSlateSnapshot.self, from: data)
        else { return }

        items = snapshot.items
        currentScene = snapshot.currentScene
        currentClip = snapshot.currentClip ?? 1
        currentSlateID = snapshot.currentSlateID
        sceneThumbnails = snapshot.sceneThumbnails ?? [:]
    }

    private func save() {
        guard !isLoading else { return }

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let snapshot = VlogSlateSnapshot(
                items: items,
                currentScene: currentScene,
                currentClip: currentClip,
                currentSlateID: currentSlateID,
                sceneThumbnails: sceneThumbnails
            )
            let data = try JSONEncoder.vlogSlate.encode(snapshot)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save VlogSlate data: \(error)")
        }
    }
}

// MARK: - Models

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

    var displayTitle: String {
        "\(scene) 场 - \(clip) 镜 - \(take) 次"
    }

    /// Used by search token matching
    var title: String { displayTitle }
}

struct VlogSlatePayload: Codable {
    var id: String
    var scene: Int
    var clip: Int
    var take: Int

    var visibleLabel: String {
        "S\(scene) C\(clip) T\(take)"
    }

    var qrString: String {
        guard let data = try? JSONEncoder.vlogSlate.encode(self),
              let string = String(data: data, encoding: .utf8)
        else { return visibleLabel }
        return string
    }
}

// MARK: - Persistence

private struct VlogSlateSnapshot: Codable {
    var items: [FootageItem]
    var currentScene: Int
    var currentClip: Int?
    var currentSlateID: String
    var sceneThumbnails: [Int: String]?
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

struct VlogExportSnapshot: Codable {
    var items: [FootageItem]
    var currentScene: Int
    var currentTake: Int
}

// MARK: - Encoder/Decoder

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

// MARK: - UTType

extension UTType {
    static let vlogSlate = UTType(exportedAs: "com.openai.vlogslate")
}

// MARK: - FootageItemBinding

struct FootageItemBinding: Identifiable {
    let id: String
}
