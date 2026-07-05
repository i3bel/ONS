import SwiftUI

// MARK: - Recipe Detail (read-only, colored text, tags)

struct RecipeDetailView: View {
    @Environment(RecipeStore.self) private var store
    @Environment(CookingController.self) private var cooking
    @Environment(\.dismiss) private var dismiss
    @State var recipe: Recipe

    @State private var showGroceries = false
    @State private var showEdit = false
    @State private var showDelete = false
    @State private var showScale = false
    @State private var scaleServings: Int?

    private var displayServings: Int { scaleServings ?? recipe.servings }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroSection
                actionButtons
                infoBar
                ingredientsSection
                methodSection
                tagsSection
            }
        }
        .background(Color.pageBg)
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showGroceries) { AddToGroceriesSheet(recipe: recipe) }
        .sheet(isPresented: $showEdit) { RecipeEditView(existingRecipe: recipe) }
        .onChange(of: showEdit) { _, isPresented in
            if !isPresented, let updated = store.recipes.first(where: { $0.id == recipe.id }) {
                recipe = updated
            }
        }
        .alert("Delete Recipe", isPresented: $showDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { store.delete(recipe); dismiss() }
        } message: { Text("Delete \"\(recipe.name)\"?") }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.bodyText.weight(.semibold)).foregroundColor(.white)
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button("Edit Recipe", systemImage: "pencil") { showEdit = true }
                Button("Delete Recipe", systemImage: "trash", role: .destructive) { showDelete = true }
            } label: {
                Image(systemName: "ellipsis").font(.title2).foregroundColor(.white)
            }
        }
    }

    // MARK: Hero

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            if let url = store.photoURL(for: recipe), let img = UIImage(contentsOfFile: url.path) {
                Image(uiImage: img).resizable().scaledToFill().frame(height: 360).clipped()
            } else {
                LinearGradient(
                    colors: [.brandBlue.opacity(0.3), .brandBlue.opacity(0.1)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ).frame(height: 360)
            }
            LinearGradient(
                colors: [.black.opacity(0.5), .clear],
                startPoint: .bottom, endPoint: .center
            ).frame(height: 360)

            VStack(alignment: .leading, spacing: 8) {
                Text(recipe.name).font(.title1).foregroundColor(.white)
            }
            .padding(.leading, 20).padding(.bottom, 20)
        }
    }

    // MARK: Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: {
                cooking.startCooking(steps: recipe.steps, recipeName: recipe.name)
                dismiss()
            }) {
                Label("Start", systemImage: "play.fill")
                    .font(.bodyText.weight(.semibold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(Color.accentGreen).clipShape(Capsule())
            }

            Spacer()

            Button(action: { showGroceries = true }) {
                Image(systemName: "basket").font(.title2).foregroundColor(.brandBlue)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.cardBg).stroke(Color.dividerColor, lineWidth: 1))
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
    }

    // MARK: Info Bar

    private var infoBar: some View {
        HStack(spacing: 16) {
            pillLabel("👥 \(displayServings)")
            if recipe.totalTime > 0 {
                pillLabel("⏱ Prep \(timeStr(recipe.prepTime)) · Cook \(timeStr(recipe.cookTime))")
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 16)
    }

    private func pillLabel(_ text: String) -> some View {
        Text(text).font(.calloutText).foregroundColor(.textSecondary)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color.cardBg).clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.dividerColor, lineWidth: 1))
    }

    // MARK: Ingredients

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Ingredients").font(.title2)
                Spacer()
                scaleButton
            }
            .padding(.horizontal, 20)

            if showScale { scaleSlider }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.element.id) { i, ing in
                    let amountUnit = showScale
                        ? recipe.scaledAmount(for: ing, targetServings: displayServings)
                        : ing.amountWithUnit
                    ingredientLine(name: ing.name, amountUnit: amountUnit)
                }
            }
            .padding(16)
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var scaleButton: some View {
        if showScale {
            Button(action: commitScale) {
                Text("\(displayServings) servings").font(.calloutText).foregroundColor(.brandBlue)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.brandedLightBlue).clipShape(Capsule())
            }
        } else {
            Button(action: { withAnimation { showScale = true; scaleServings = recipe.servings } }) {
                Text("Scale").font(.calloutText).foregroundColor(.brandBlue)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.brandedLightBlue).clipShape(Capsule())
            }
        }
    }

    private var scaleSlider: some View {
        HStack(spacing: 12) {
            Slider(
                value: Binding(get: { Double(displayServings) }, set: { scaleServings = Int($0) }),
                in: 1...20, step: 1
            )
            .tint(.brandBlue)
            Text("\(displayServings) 份").font(.bodyText.weight(.semibold)).foregroundColor(.brandBlue)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 20).padding(.vertical, 4)
    }

    private func commitScale() {
        withAnimation {
            var updated = recipe
            let scale = Double(displayServings) / Double(recipe.servings)
            updated.ingredients = updated.ingredients.map { ing in
                guard !Ingredient.fuzzyQuantifiers.contains(ing.unit) else { return ing }
                var scaled = ing
                scaled.amount = ing.amount * scale
                return scaled
            }
            updated.servings = displayServings
            store.update(updated)
            recipe = updated
            showScale = false
            scaleServings = nil
        }
    }

    private func ingredientLine(name: String, amountUnit: String) -> some View {
        HStack {
            Text(amountUnit).font(.bodyText.weight(.semibold)).foregroundColor(.brandBlue)
            + Text("  \(name)").font(.bodyText).foregroundColor(.textPrimary)
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }

    // MARK: Method

    private var methodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Method").font(.title2)
                .padding(.horizontal, 20).padding(.top, 16)

            ForEach(Array(recipe.steps.enumerated()), id: \.element.id) { i, step in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle().fill(Color.brandBlue).frame(width: 28, height: 28)
                        Text("\(i + 1)").font(.calloutText.weight(.bold)).foregroundColor(.white)
                    }

                    recipeColoredText(step.description)
                        .font(.bodyText).lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 20)
    }

    /// Renders step text with ingredient names (blue), times (red), temperatures (orange).
    private func recipeColoredText(_ text: String) -> Text {
        let ingredientsSorted = recipe.ingredients.sorted { $0.name.count > $1.name.count }
        let rules: [HighlightRule] = [
            .init(strings: ingredientsSorted.map(\.name), color: .brandBlue),
            .init(pattern: RecipeTextPatterns.time, color: .accentRed),
            .init(pattern: RecipeTextPatterns.temperature, color: .accentOrange),
        ]
        return highlightText(text, rules: rules)
    }

    // MARK: Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags").font(.title2)
                .padding(.horizontal, 20).padding(.top, 12)

            if !recipe.tags.isEmpty {
                TagFlowLayout(spacing: 8) {
                    ForEach(recipe.tags, id: \.self) { tag in
                        Text("#\(tag)").font(.calloutText).foregroundColor(.brandBlue)
                            .padding(.horizontal, 16).padding(.vertical, 6)
                            .background(Color.brandedLightBlue).clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
            }

            Text("").frame(height: 16)
        }
        .padding(.bottom, 20)
    }

    private func timeStr(_ t: TimeInterval) -> String {
        let m = Int(t / 60); return m > 0 ? "\(m)min" : "0min"
    }
}

// MARK: - Add to Groceries Sheet

private struct AddToGroceriesSheet: View {
    @Environment(RecipeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var recipe: Recipe
    @State private var selected = Set<String>()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    ForEach(recipe.ingredients) { ing in
                        ingredientRow(ing)
                    }
                }
                .listStyle(.plain).background(Color.pageBg)
                .navigationTitle("Add to Groceries")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                            .font(.bodyText.weight(.medium)).foregroundColor(.textPrimary)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color.cardBg).clipShape(Capsule())
                    }
                }

                bottomBar
            }
        }
    }

    private func ingredientRow(_ ing: Ingredient) -> some View {
        HStack(spacing: 12) {
            Button(action: { selected.formUnion([ing.id]) }) {
                Image(systemName: selected.contains(ing.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title2).foregroundColor(selected.contains(ing.id) ? .brandBlue : .textSecondary)
            }
            .buttonStyle(.plain)

            Text(ing.displayString).font(.bodyText)

            Spacer()

            Button(action: { selected.remove(ing.id) }) {
                Image(systemName: "xmark.circle.fill").font(.title3).foregroundColor(.accentRed)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 12))
        .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowSeparator(.hidden).listRowBackground(Color.clear)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button(selected.count == recipe.ingredients.count ? "Deselect All" : "Select All") {
                if selected.count == recipe.ingredients.count { selected.removeAll() }
                else { selected = Set(recipe.ingredients.map(\.id)) }
            }
            .font(.bodyText.weight(.semibold)).foregroundColor(.brandBlue)
            .frame(maxWidth: .infinity).frame(height: 48)
            .background(Color.brandedLightBlue).clipShape(Capsule())

            Button("Add \(selected.count) Items") {
                let items = recipe.ingredients.filter { selected.contains($0.id) }
                store.addShoppingItems(items)
                dismiss()
            }
            .font(.bodyText.weight(.semibold)).foregroundColor(.white)
            .frame(maxWidth: .infinity).frame(height: 48)
            .background(Color.brandBlue).clipShape(Capsule())
            .disabled(selected.isEmpty)
        }
        .background(.regularMaterial)
    }
}

// MARK: - Highlight Engine (shared across RecipeDetailView and CookModeView)

struct HighlightRule {
    var pattern: String?
    var strings: [String]?
    var color: Color
}

func highlightText(_ text: String, rules: [HighlightRule]) -> Text {
    var result = Text("")
    var remaining = text

    while !remaining.isEmpty {
        var earliestStart = remaining.endIndex
        var earliestRange: Range<String.Index>?
        var earliestColor: Color?

        for rule in rules {
            if let strings = rule.strings {
                for s in strings {
                    if let r = remaining.range(of: s, options: .caseInsensitive), r.lowerBound < earliestStart {
                        earliestStart = r.lowerBound; earliestRange = r; earliestColor = rule.color
                    }
                }
            }
            if let pattern = rule.pattern {
                if let r = remaining.range(of: pattern, options: .regularExpression), r.lowerBound < earliestStart {
                    earliestStart = r.lowerBound; earliestRange = r; earliestColor = rule.color
                }
            }
        }

        if let r = earliestRange, let color = earliestColor {
            let before = String(remaining[remaining.startIndex..<r.lowerBound])
            if !before.isEmpty { result = result + Text(before).foregroundColor(.textPrimary) }
            result = result + Text(String(remaining[r])).foregroundColor(color).fontWeight(.bold)
            remaining = String(remaining[r.upperBound...])
            continue
        }

        result = result + Text(String(remaining.first!)).foregroundColor(.textPrimary)
        remaining = String(remaining.dropFirst())
    }
    return result
}

// MARK: - Tag Flow Layout

private struct TagFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? 300
        var y: CGFloat = 0, x: CGFloat = 0, rowH: CGFloat = 0
        for sv in subviews {
            let sz = sv.sizeThatFits(.unspecified)
            if x + sz.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            rowH = max(rowH, sz.height)
            x += sz.width + spacing
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for sv in subviews {
            let sz = sv.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            sv.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            rowH = max(rowH, sz.height)
            x += sz.width + spacing
        }
    }
}
