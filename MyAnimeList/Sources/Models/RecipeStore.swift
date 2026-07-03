import Foundation
import Observation
import UniformTypeIdentifiers

// MARK: - Recipe Store

@Observable
final class RecipeStore {
    var recipes: [Recipe] = []

    private let fileURL: URL
    private var isLoading = false

    init() {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = supportDirectory.appendingPathComponent("VlogSlate", isDirectory: true)
        fileURL = directory.appendingPathComponent("recipes.json")
        load()
    }

    // MARK: - CRUD

    func addRecipe(_ recipe: Recipe) {
        recipes.insert(recipe, at: 0)
        save()
    }

    func deleteRecipe(_ recipe: Recipe) {
        recipes.removeAll { $0.id == recipe.id }
        // Clean up thumbnail
        if let filename = recipe.thumbnailFilename {
            let url = fileURL.deletingLastPathComponent().appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: url)
        }
        save()
    }

    func updateRecipe(_ recipe: Recipe) {
        guard let idx = recipes.firstIndex(where: { $0.id == recipe.id }) else { return }
        recipes[idx] = recipe
        save()
    }

    func thumbnailURL(for recipe: Recipe) -> URL? {
        guard let filename = recipe.thumbnailFilename else { return nil }
        return fileURL.deletingLastPathComponent().appendingPathComponent(filename)
    }

    func saveThumbnail(data: Data, for recipeID: String) -> String? {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filename = "recipe_\(recipeID)_thumb.jpg"
        let url = dir.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: [.atomic])
            return filename
        } catch {
            print("Failed to save recipe thumbnail: \(error)")
            return nil
        }
    }

    // MARK: - Persistence

    private func load() {
        isLoading = true
        defer { isLoading = false }
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder.recipeStore.decode(RecipeSnapshot.self, from: data)
        else { return }
        recipes = snapshot.recipes
    }

    func save() {
        guard !isLoading else { return }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let snapshot = RecipeSnapshot(recipes: recipes)
            let data = try JSONEncoder.recipeStore.encode(snapshot)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save recipes: \(error)")
        }
    }
}

private struct RecipeSnapshot: Codable {
    var recipes: [Recipe]
}

extension JSONEncoder {
    static var recipeStore: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var recipeStore: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

// MARK: - Recipe Model

struct Recipe: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var thumbnailFilename: String?
    var defaultServings: Int = 1
    var status: RecipeStatus = .neutral
    var notes: String = ""
    var ingredients: [Ingredient] = []
    var steps: [CookingStep] = []
    var createdAt: Date = .now

    func scaledIngredients(for servings: Int) -> [Ingredient] {
        guard defaultServings > 0 else { return ingredients }
        let scale = Double(servings) / Double(defaultServings)
        return ingredients.map { ingredient in
            Ingredient(
                id: ingredient.id,
                name: ingredient.name,
                amount: ingredient.amount * scale,
                unit: ingredient.unit,
                category: ingredient.category,
                isPrepared: ingredient.isPrepared
            )
        }
    }
}

enum RecipeStatus: String, Codable, CaseIterable {
    case wantToEat = "想吃"
    case neutral = "一般"
    case favorite = "最爱吃"
    case worst = "最难吃"

    var systemImage: String {
        switch self {
        case .wantToEat: return "heart"
        case .neutral: return "minus"
        case .favorite: return "heart.fill"
        case .worst: return "hand.thumbsdown"
        }
    }
}

// MARK: - Ingredient Model

struct Ingredient: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var amount: Double
    var unit: String
    var category: IngredientCategory = .other
    var isPrepared: Bool = false

    var displayAmount: String {
        if amount == 0 { return "适量" }
        if amount == floor(amount) {
            return "\(Int(amount)) \(unit)"
        }
        return String(format: "%.1f %@", amount, unit)
    }
}

enum IngredientCategory: String, Codable, CaseIterable {
    case vegetable = "蔬菜"
    case meat = "肉类"
    case seafood = "海鲜"
    case seasoning = "调料"
    case dairy = "乳制品"
    case dry = "干货"
    case grain = "主食"
    case fruit = "水果"
    case other = "其他"

    var systemImage: String {
        switch self {
        case .vegetable: return "leaf"
        case .meat: return "flame"
        case .seafood: return "fish"
        case .seasoning: return "drop"
        case .dairy: return "cup.and.saucer"
        case .dry: return "archivebox"
        case .grain: return "crown"
        case .fruit: return "applelogo"
        case .other: return "questionmark"
        }
    }
}

// MARK: - Cooking Step Model

struct CookingStep: Identifiable, Codable, Equatable {
    var id: String
    var order: Int
    var description: String
    var duration: TimeInterval? = nil

    var hasTimer: Bool {
        guard let d = duration, d > 0 else { return false }
        return true
    }

    var durationDisplay: String {
        guard let d = duration, d > 0 else { return "" }
        let totalMinutes = Int(d / 60)
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            return "\(hours)小时\(mins)分钟"
        }
        return "\(totalMinutes)分钟"
    }
}
