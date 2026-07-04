import Foundation
import Observation
import UniformTypeIdentifiers

// MARK: - Recipe Model

struct Recipe: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var servings: Int
    var prepTime: TimeInterval
    var cookTime: TimeInterval
    var ingredients: [Ingredient]
    var steps: [CookingStep]
    var photoFilename: String?
    var tags: [String]
    var createdAt: Date

    var totalTime: TimeInterval { prepTime + cookTime }

    init(id: String = UUID().uuidString, name: String, servings: Int = 2, prepTime: TimeInterval = 0, cookTime: TimeInterval = 0, ingredients: [Ingredient] = [], steps: [CookingStep] = [], photoFilename: String? = nil, tags: [String] = [], createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.servings = servings
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.ingredients = ingredients
        self.steps = steps
        self.photoFilename = photoFilename
        self.tags = tags
        self.createdAt = createdAt
    }

    /// Scale an ingredient by target servings
    func scaledAmount(for ingredient: Ingredient, targetServings: Int) -> String {
        guard servings > 0 else { return ingredient.displayString }
        let scale = Double(targetServings) / Double(servings)
        let scaled = ingredient.amount * scale
        if scaled == floor(scaled) {
            return "\(Int(scaled)) \(ingredient.unit)"
        }
        return String(format: "%.1f \(ingredient.unit)", scaled)
    }
}

// MARK: - Ingredient

struct Ingredient: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var amount: Double
    var unit: String

    var displayString: String {
        if amount == floor(amount) {
            return "\(Int(amount)) \(unit) \(name)"
        }
        return String(format: "%.1f %@ %@", amount, unit, name)
    }

    init(id: String = UUID().uuidString, name: String, amount: Double, unit: String) {
        self.id = id
        self.name = name
        self.amount = amount
        self.unit = unit
    }

    /// Parse Chinese text like "一勺糖" → Ingredient(name:"糖", amount:1, unit:"勺")
    static func parseChinese(_ text: String) -> Ingredient {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let chineseDigits: [Character: Double] = [
            "零": 0, "一": 1, "二": 2, "三": 3, "四": 4, "五": 5,
            "六": 6, "七": 7, "八": 8, "九": 9, "十": 10
        ]
        let knownUnits = ["杯", "碗", "勺", "汤匙", "茶匙", "个", "根", "片", "只", "粒",
                          "颗", "瓣", "块", "条", "束", "包", "盒", "瓶", "罐",
                          "克", "毫升", "斤", "两", "公斤", "升", "头", "把",
                          "ml", "g", "kg", "cup", "tbsp", "tsp", "oz", "lb", "pinch"]
        let fuzzyQuantifiers = ["一勺半", "两勺半", "适量", "少许", "少量", "若干"]

        // Check fuzzy quantifiers first
        for q in fuzzyQuantifiers {
            if trimmed.hasPrefix(q) {
                let name = String(trimmed.dropFirst(q.count)).trimmingCharacters(in: .whitespaces)
                return Ingredient(name: name.isEmpty ? trimmed : name, amount: 0, unit: q)
            }
        }

        var amount: Double = 1
        var unit = ""
        var name = trimmed

        // Handle "两" (special: means 2, not 2)
        if trimmed.hasPrefix("两") {
            amount = 2
            name = String(trimmed.dropFirst())
        }
        // Handle "半" at start (means 0.5)
        else if trimmed.hasPrefix("半") {
            amount = 0.5
            name = String(trimmed.dropFirst())
        }
        else {
            // Extract amount from Chinese digits at start
            for (char, val) in chineseDigits {
                if trimmed.hasPrefix(String(char)) {
                    amount = val
                    name = String(trimmed.dropFirst(String(char).count))
                    break
                }
            }
        }

        // Try Arabic digits at start
        if amount >= 1, let firstDigit = trimmed.first, firstDigit.isNumber {
            let digits = trimmed.prefix(while: \.isNumber)
            if let parsed = Double(digits) {
                amount = parsed
                name = String(trimmed.dropFirst(digits.count))
            }
        }

        // Handle "X勺半" pattern (e.g. "一勺半" = 1.5勺)
        for u in ["勺", "杯", "碗", "汤匙", "茶匙", "个", "头", "把"] {
            if name.hasPrefix(u) && name.dropFirst(u.count).hasPrefix("半") {
                unit = u
                amount += 0.5
                name = String(name.dropFirst(u.count + 1)).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        // Extract unit
        if unit.isEmpty {
            name = name.trimmingCharacters(in: .whitespaces)
            for u in knownUnits {
                if name.hasPrefix(u) {
                    unit = u
                    name = String(name.dropFirst(u.count)).trimmingCharacters(in: .whitespaces)
                    break
                }
            }
        }

        return Ingredient(name: name.isEmpty ? trimmed : name, amount: amount, unit: unit)
    }
}

// MARK: - Cooking Step

struct CookingStep: Identifiable, Codable, Equatable {
    var id: String
    var order: Int
    var description: String

    init(id: String = UUID().uuidString, order: Int, description: String) {
        self.id = id
        self.order = order
        self.description = description
    }
}

// MARK: - Recipe Store

@Observable
final class RecipeStore {
    var recipes: [Recipe] = []
    var sortOrder: SortOrder = .name

    enum SortOrder: String, Codable { case name, prepTime }

    private let fileURL: URL
    private var isLoading = false

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RecipeSlate", isDirectory: true)
        fileURL = dir.appendingPathComponent("recipes.json")
        load()
    }

    var sortedRecipes: [Recipe] {
        switch sortOrder {
        case .name: return recipes.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .prepTime: return recipes.sorted { $0.totalTime < $1.totalTime }
        }
    }

    func add(_ recipe: Recipe) { recipes.append(recipe); save() }
    func update(_ recipe: Recipe) { guard let i = recipes.firstIndex(where: { $0.id == recipe.id }) else { return }; recipes[i] = recipe; save() }
    func delete(_ recipe: Recipe) { recipes.removeAll { $0.id == recipe.id }; save() }
    func delete(_ recipes: [Recipe]) { let ids = Set(recipes.map(\.id)); self.recipes.removeAll { ids.contains($0.id) }; save() }

    func savePhoto(data: Data, for recipeID: String) -> String? {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fn = "photo_\(recipeID).jpg"
        let url = dir.appendingPathComponent(fn)
        do { try data.write(to: url, options: .atomic); return fn } catch { return nil }
    }

    func photoURL(for recipe: Recipe) -> URL? {
        guard let fn = recipe.photoFilename else { return nil }
        return fileURL.deletingLastPathComponent().appendingPathComponent(fn)
    }

    private func load() {
        isLoading = true; defer { isLoading = false }
        guard let data = try? Data(contentsOf: fileURL),
              let snap = try? JSONDecoder.recipeStore.decode(Snapshot.self, from: data) else { return }
        recipes = snap.recipes; sortOrder = snap.sortOrder
    }

    func save() {
        guard !isLoading else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let snap = Snapshot(recipes: recipes, sortOrder: sortOrder)
        if let data = try? JSONEncoder.recipeStore.encode(snap) { try? data.write(to: fileURL, options: .atomic) }
    }
}

private struct Snapshot: Codable {
    var recipes: [Recipe]
    var sortOrder: RecipeStore.SortOrder
}

extension JSONEncoder { static var recipeStore: JSONEncoder { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e } }
extension JSONDecoder { static var recipeStore: JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d } }
