import SwiftUI

// MARK: - Price Calculator

struct PriceCalculatorView: View {
    @Environment(RecipeStore.self) private var store
    @State private var mode: PriceMode = .takeout

    enum PriceMode: String, CaseIterable {
        case takeout = "外卖"
        case homemade = "自制"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode Picker
                Picker("模式", selection: $mode) {
                    ForEach(PriceMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                switch mode {
                case .takeout:
                    TakeoutView()
                case .homemade:
                    HomemadeView()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("计价")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Takeout Mode

private struct TakeoutView: View {
    @State private var items: [TakeoutItem] = []
    @State private var newName = ""
    @State private var newPrice = ""

    private var total: Double {
        items.reduce(0) { $0 + $1.price }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Add item
                GlassCard {
                    HStack(spacing: 8) {
                        TextField("菜品名", text: $newName)
                            .font(.subheadline)
                        TextField("价格", text: $newPrice)
                            .keyboardType(.decimalPad)
                            .font(.subheadline)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                        Button("添加") {
                            guard let price = Double(newPrice), price > 0, !newName.isEmpty else { return }
                            items.append(TakeoutItem(name: newName, price: price))
                            newName = ""
                            newPrice = ""
                        }
                        .font(.subheadline.weight(.semibold))
                        .disabled(newName.isEmpty || newPrice.isEmpty)
                    }
                }

                // Item list
                if !items.isEmpty {
                    GlassCard {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            HStack {
                                Text(item.name)
                                    .font(.subheadline)
                                Spacer()
                                Text("¥\(item.price, specifier: "%.2f")")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    items.remove(at: index)
                                } label: { Image(systemName: "trash") }
                            }
                        }
                    }
                }

                // Total
                if !items.isEmpty {
                    GlassCard {
                        HStack {
                            Text("合计")
                                .font(.title3.weight(.bold))
                            Spacer()
                            Text("¥\(total, specifier: "%.2f")")
                                .font(.title.weight(.bold))
                                .foregroundStyle(.orange)
                        }

                        HStack {
                            Text("\(items.count) 项")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("¥\(total / Double(max(1, items.count)), specifier: "%.2f") / 项")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

private struct TakeoutItem: Identifiable {
    var id = UUID()
    var name: String
    var price: Double
}

// MARK: - Homemade Mode

private struct HomemadeView: View {
    @Environment(RecipeStore.self) private var store
    @State private var selectedRecipeID: String? = nil
    @State private var unitPrices: [String: Double] = [:]
    @State private var showRecipePicker = false

    private var selectedRecipe: Recipe? {
        guard let id = selectedRecipeID else { return nil }
        return store.recipes.first { $0.id == id }
    }

    private var totalIngredientCost: Double {
        guard let recipe = selectedRecipe else { return 0 }
        return recipe.ingredients.reduce(0) { total, ing in
            let unitPrice = unitPrices[ing.id, default: 0]
            return total + (ing.amount * unitPrice)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Recipe selector
                GlassCard {
                    Button(action: { showRecipePicker = true }) {
                        HStack {
                            Image(systemName: "book")
                                .foregroundStyle(.orange)
                            Text(selectedRecipe?.name ?? "选择菜谱")
                                .foregroundStyle(selectedRecipe != nil ? .primary : .secondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                if let recipe = selectedRecipe {
                    // Price Section
                    GlassCard {
                        Label("食材价格", systemImage: "dollarsign.circle")
                            .font(.headline)

                        ForEach(recipe.ingredients) { ingredient in
                            HStack(spacing: 8) {
                                Text(ingredient.name)
                                    .font(.subheadline)
                                Text(ingredient.displayAmount)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                TextField("单价", value: Binding(get: {
                                    unitPrices[ingredient.id, default: 0]
                                }, set: { newValue in
                                    unitPrices[ingredient.id] = newValue
                                }), format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 70)
                                    .font(.subheadline.monospacedDigit())
                                Text("元")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if let unitPrice = unitPrices[ingredient.id], unitPrice > 0 {
                                    Text("= ¥\(ingredient.amount * unitPrice, specifier: "%.1f")")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 60, alignment: .trailing)
                                }
                            }
                            .padding(.vertical, 2)
                        }

                        Divider()
                        HStack {
                            Text("食材合计")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("¥\(totalIngredientCost, specifier: "%.2f")")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.orange)
                        }
                    }

                    // Time Section
                    GlassCard {
                        Label("制作时间", systemImage: "clock")
                            .font(.headline)

                        VStack(spacing: 8) {
                            HStack {
                                Text("准备时间")
                                Spacer()
                                Text(timeDisplay(recipe.prepTime))
                                    .font(.body.monospacedDigit().weight(.medium))
                            }
                            HStack {
                                Text("烹饪时间")
                                Spacer()
                                Text(timeDisplay(recipe.cookTime))
                                    .font(.body.monospacedDigit().weight(.medium))
                            }
                            Divider()
                            HStack {
                                Text("总用时")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(timeDisplay(recipe.totalTime))
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showRecipePicker) {
            NavigationStack {
                List(store.recipes) { recipe in
                    Button(action: {
                        selectedRecipeID = recipe.id
                        showRecipePicker = false
                    }) {
                        HStack {
                            Text(recipe.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if recipe.id == selectedRecipeID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                .navigationTitle("选择菜谱")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("取消") { showRecipePicker = false }
                    }
                }
            }
        }
    }

    private func timeDisplay(_ interval: TimeInterval) -> String {
        let total = Int(interval / 60)
        if total >= 60 {
            let hours = total / 60
            let mins = total % 60
            if mins > 0 { return "\(hours)小时\(mins)分钟" }
            return "\(hours)小时"
        }
        return "\(total)分钟"
    }
}

// MARK: - Glass Card (reused)

private struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
}
