import Foundation
import Observation

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

    init(id: String = UUID().uuidString, name: String, servings: Int = 2,
         prepTime: TimeInterval = 0, cookTime: TimeInterval = 0,
         ingredients: [Ingredient] = [], steps: [CookingStep] = [],
         photoFilename: String? = nil, tags: [String] = [], createdAt: Date = .now) {
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

    /// Scale an ingredient by target servings (returns "amount unit" without ingredient name)
    func scaledAmount(for ingredient: Ingredient, targetServings: Int) -> String {
        if Ingredient.fuzzyQuantifiers.contains(ingredient.unit) {
            return ingredient.unit
        }
        guard servings > 0 else { return ingredient.amountWithUnit }
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

    /// Quantifiers like "适量" that negate numeric scaling.
    static let fuzzyQuantifiers = ["适量", "少许", "少量", "若干"]

    /// Precomputed list of known Chinese/English units for parsing.
    static let knownUnits = [
        "杯", "碗", "勺", "汤匙", "茶匙", "个", "根", "片", "只", "粒",
        "颗", "瓣", "块", "条", "束", "包", "盒", "瓶", "罐",
        "克", "毫升", "斤", "两", "公斤", "升", "头", "把",
        "ml", "g", "kg", "cup", "tbsp", "tsp", "oz", "lb", "pinch"
    ]

    /// "1.5 勺" — amount + unit without ingredient name
    var amountWithUnit: String {
        if Self.fuzzyQuantifiers.contains(unit) { return unit }
        if amount == floor(amount) { return "\(Int(amount)) \(unit)" }
        return String(format: "%.1f %@", amount, unit)
    }

    /// "1.5 勺 糖" — full display string
    var displayString: String {
        if Self.fuzzyQuantifiers.contains(unit) { return "\(unit) \(name)" }
        if amount == floor(amount) { return "\(Int(amount)) \(unit) \(name)" }
        return String(format: "%.1f %@ %@", amount, unit, name)
    }

    init(id: String = UUID().uuidString, name: String, amount: Double, unit: String) {
        self.id = id
        self.name = name
        self.amount = amount
        self.unit = unit
    }

    // MARK: - Chinese Text Parser

    /// Parse Chinese text like "一勺糖" → Ingredient(name:"糖", amount:1, unit:"勺")
    static func parseChinese(_ text: String) -> Ingredient {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let chineseDigits: [Character: Double] = [
            "零": 0, "一": 1, "二": 2, "三": 3, "四": 4, "五": 5,
            "六": 6, "七": 7, "八": 8, "九": 9, "十": 10
        ]

        // Fuzzy quantifiers first
        for q in Self.fuzzyQuantifiers {
            if trimmed.hasPrefix(q) {
                let name = String(trimmed.dropFirst(q.count)).trimmingCharacters(in: .whitespaces)
                return Ingredient(name: name.isEmpty ? trimmed : name, amount: 0, unit: q)
            }
        }

        var amount: Double = 1
        var unit = ""
        var name = trimmed

        if trimmed.hasPrefix("两") {
            amount = 2
            name = String(trimmed.dropFirst())
        } else if trimmed.hasPrefix("半") {
            amount = 0.5
            name = String(trimmed.dropFirst())
        } else {
            for (char, val) in chineseDigits {
                if trimmed.hasPrefix(String(char)) {
                    amount = val
                    name = String(trimmed.dropFirst(String(char).count))
                    break
                }
            }
        }

        // Arabic digits at start
        if let firstDigit = trimmed.first, firstDigit.isNumber || firstDigit == "." {
            let digits = trimmed.prefix(while: { $0.isNumber || $0 == "." })
            if let parsed = Double(digits) {
                amount = parsed
                name = String(trimmed.dropFirst(digits.count))
            }
        }

        // "X勺半" pattern (e.g. "一勺半" = 1.5勺)
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
            for u in Self.knownUnits {
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

// MARK: - Shared Recipe Text Patterns

enum RecipeTextPatterns {
    /// Matches time expressions: "20分钟", "30 min", "2小时", "一刻", etc.
    static let time = #"(?:\d+\s*(?:min(?:ute)?s?|mins|秒|hour(?:s)?|分钟|小时|分|天|周|个月|年))|(?:[一两二三四五六七八九十半几数]+\s*(?:分钟|小时|天|周|个月|年))|一刻|一会|一会儿|片刻|半天|半个月|半年|半日|数日"#

    /// Matches temperature: "180°C", "350°F", "200度"
    static let temperature = #"\d+\s*(°[FC]|度)"#
}

// MARK: - Recipe Store

@Observable
final class RecipeStore {
    var recipes: [Recipe] = []
    var sortOrder: SortOrder = .name
    var shoppingItems: [Ingredient] = []

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
        case .name:
            return recipes.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .prepTime:
            return recipes.sorted { $0.totalTime < $1.totalTime }
        }
    }

    // MARK: - CRUD

    func add(_ recipe: Recipe) { recipes.append(recipe); save() }
    func update(_ recipe: Recipe) {
        guard let i = recipes.firstIndex(where: { $0.id == recipe.id }) else { return }
        recipes[i] = recipe; save()
    }
    func delete(_ recipe: Recipe) { recipes.removeAll { $0.id == recipe.id }; save() }
    func delete(_ recipes: [Recipe]) {
        let ids = Set(recipes.map(\.id))
        self.recipes.removeAll { ids.contains($0.id) }; save()
    }

    // MARK: - Photos

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

    // MARK: - Shopping List

    func addShoppingItems(_ items: [Ingredient]) {
        for item in items { mergeOrAdd(item) }
        save()
    }

    func addShoppingItem(_ item: Ingredient) {
        mergeOrAdd(item)
        save()
    }

    func removeShoppingItem(_ id: String) {
        shoppingItems.removeAll { $0.id == id }
        save()
    }

    func clearShoppingList() {
        shoppingItems.removeAll()
        save()
    }

    /// Merge duplicate ingredients by name+unit before adding.
    private func mergeOrAdd(_ item: Ingredient) {
        // Same name + same unit → merge amounts
        if let idx = shoppingItems.firstIndex(where: { $0.name == item.name && $0.unit == item.unit }) {
            if Ingredient.fuzzyQuantifiers.contains(item.unit) { return }
            let existing = shoppingItems[idx]
            shoppingItems[idx] = Ingredient(
                id: existing.id,
                name: existing.name,
                amount: existing.amount + item.amount,
                unit: existing.unit
            )
            return
        }

        // Same name, both fuzzy → keep existing
        if let idx = shoppingItems.firstIndex(where: { $0.name == item.name }),
           Ingredient.fuzzyQuantifiers.contains(item.unit),
           Ingredient.fuzzyQuantifiers.contains(shoppingItems[idx].unit) {
            return
        }

        shoppingItems.append(item)
    }

    // MARK: - Clear All

    func clearAll() {
        recipes.removeAll()
        shoppingItems.removeAll()
        let dir = fileURL.deletingLastPathComponent()
        if let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for f in files where f.lastPathComponent.hasPrefix("photo_") {
                try? FileManager.default.removeItem(at: f)
            }
        }
        save()
    }

    // MARK: - Persistence

    private func load() {
        isLoading = true; defer { isLoading = false }
        guard let data = try? Data(contentsOf: fileURL),
              let snap = try? JSONDecoder.recipeStore.decode(Snapshot.self, from: data) else { return }
        recipes = snap.recipes; sortOrder = snap.sortOrder; shoppingItems = snap.shoppingItems
    }

    func save() {
        guard !isLoading else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let snap = Snapshot(recipes: recipes, sortOrder: sortOrder, shoppingItems: shoppingItems)
        if let data = try? JSONEncoder.recipeStore.encode(snap) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}

// MARK: - Persistence Helpers

private struct Snapshot: Codable {
    var recipes: [Recipe]
    var sortOrder: RecipeStore.SortOrder
    var shoppingItems: [Ingredient] = []
}

extension JSONEncoder {
    static var recipeStore: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
}

extension JSONDecoder {
    static var recipeStore: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
