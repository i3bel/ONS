import SwiftUI

// MARK: - Recipe Detail (iOS 26 Native Style)

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
        .navigationBarBackButtonHidden(true)
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
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button("Edit Recipe", systemImage: "pencil") { showEdit = true }
                Button("Delete Recipe", systemImage: "trash", role: .destructive) { showDelete = true }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: Hero

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            if let url = store.photoURL(for: recipe), let img = UIImage(contentsOfFile: url.path) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(height: 340).clipped()
            } else {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [.accentColor.opacity(0.3), .accentColor.opacity(0.08)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(height: 340)
            }

            // Softer gradient overlay
            LinearGradient(
                colors: [.black.opacity(0.45), .clear],
                startPoint: .bottom, endPoint: .center
            )
            .frame(height: 340)

            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.name)
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 1)
            }
            .padding(.horizontal, Spacing.large)
            .padding(.bottom, Spacing.large)
        }
    }

    // MARK: Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: {
                cooking.startCooking(steps: recipe.steps, recipeName: recipe.name)
                dismiss()
            }) {
                Label("Start Cooking", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButton(color: .accentGreen))

            Button(action: { showGroceries = true }) {
                Image(systemName: "basket")
                    .font(.title3)
            }
            .buttonStyle(.bordered)
            .frame(width: 50, height: 50)
        }
        .padding(.horizontal, Spacing.large)
        .padding(.vertical, Spacing.standard)
    }

    // MARK: Info Bar

    private var infoBar: some View {
        HStack(spacing: 8) {
            InfoPill(text: "\(displayServings) servings")
            if recipe.totalTime > 0 {
                InfoPill(text: "Prep \(timeStr(recipe.prepTime))  ·  Cook \(timeStr(recipe.cookTime))")
            }
        }
        .padding(.horizontal, Spacing.large)
        .padding(.bottom, Spacing.standard)
    }

    // MARK: Ingredients

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            SectionHeader(title: "Ingredients")

            Card {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(recipe.ingredients.enumerated()), id: \.element.id) { i, ing in
                        let amountUnit = showScale
                            ? recipe.scaledAmount(for: ing, targetServings: displayServings)
                            : ing.amountWithUnit
                        ingredientLine(name: ing.name, amountUnit: amountUnit)

                        if i < recipe.ingredients.count - 1 {
                            Divider()
                                .padding(.leading, 4)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.standard)

            if showScale { scaleSlider }
        }
        .padding(.vertical, Spacing.small)
    }

    @ViewBuilder
    private var scaleButton: some View {
        if showScale {
            Button(action: commitScale) {
                Text("\(displayServings) servings")
            }
            .buttonStyle(BorderedButton())
        } else {
            Button(action: { withAnimation { showScale = true; scaleServings = recipe.servings } }) {
                Text("Scale")
            }
            .buttonStyle(BorderedButton())
        }
    }

    private var scaleSlider: some View {
        HStack(spacing: 12) {
            Slider(
                value: Binding(get: { Double(displayServings) }, set: { scaleServings = Int($0) }),
                in: 1...20, step: 1
            )
            .tint(.accentColor)
            Text("\(displayServings)")
                .font(.body.weight(.semibold))
                .foregroundColor(.accentColor)
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.horizontal, Spacing.large)
        .padding(.vertical, Spacing.small)
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
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(amountUnit)
                .font(.body.weight(.semibold))
                .foregroundColor(.accentColor)
                + Text("  \(name)")
                    .font(.body)
                    .foregroundColor(.textPrimary)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: Method

    private var methodSection: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            SectionHeader(title: "Method")

            ForEach(Array(recipe.steps.enumerated()), id: \.element.id) { i, step in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray4))
                            .frame(width: 28, height: 28)
                        Text("\(i + 1)")
                            .font(.callout.weight(.bold))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 2)

                    recipeColoredText(step.description)
                        .font(.body)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Spacing.standard)
                .background(Color.cardBg, in: RoundedRectangle(cornerRadius: CornerRadius.standard))
                .padding(.horizontal, Spacing.standard)
            }
        }
        .padding(.bottom, Spacing.large)
    }

    /// Renders step text with ingredient names (blue), times (red), temperatures (orange).
    private func recipeColoredText(_ text: String) -> Text {
        let ingredientsSorted = recipe.ingredients.sorted { $0.name.count > $1.name.count }
        let rules: [HighlightRule] = [
            .init(strings: ingredientsSorted.map(\.name), color: .accentColor),
            // Half-pattern must come BEFORE time pattern (same position → longer match wins)
            .init(pattern: #"[一二两三四五六七八九十]+\s*(?:年|天|小时|分钟)\s*半"#, color: .accentRed),
            .init(pattern: RecipeTextPatterns.time, color: .accentRed),
            .init(pattern: RecipeTextPatterns.temperature, color: .accentOrange),
        ]
        return highlightText(text, rules: rules)
    }

    // MARK: Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            SectionHeader(title: "Tags")

            if !recipe.tags.isEmpty {
                TagFlowLayout(spacing: 8) {
                    ForEach(recipe.tags, id: \.self) { tag in
                        InfoPill(text: "#\(tag)", color: .accentColor, bg: Color(.systemFill))
                    }
                }
                .padding(.horizontal, Spacing.standard)
            }
        }
        .padding(.bottom, Spacing.large)
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
                    .font(.title3)
                    .foregroundColor(selected.contains(ing.id) ? .accentColor : .textSecondary)
            }
            .buttonStyle(.plain)

            Text(ing.displayString)
                .font(.body)
                .strikethrough(selected.contains(ing.id))
                .foregroundColor(selected.contains(ing.id) ? .textSecondary : .textPrimary)

            Spacer()

            if selected.contains(ing.id) {
                Button(action: { selected.remove(ing.id) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.standard)
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: CornerRadius.standard))
        .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowSeparator(.hidden).listRowBackground(Color.clear)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button(selected.count == recipe.ingredients.count ? "Deselect All" : "Select All") {
                if selected.count == recipe.ingredients.count { selected.removeAll() }
                else { selected = Set(recipe.ingredients.map(\.id)) }
            }
            .buttonStyle(BorderedButton())

            Button("Add \(selected.count) Items") {
                let items = recipe.ingredients.filter { selected.contains($0.id) }
                store.addShoppingItems(items)
                dismiss()
            }
            .buttonStyle(PrimaryButton())
            .disabled(selected.isEmpty)
        }
        .padding(.horizontal, Spacing.standard)
        .padding(.vertical, 12)
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
                    if let r = remaining.range(of: s, options: .caseInsensitive) {
                        // Prefer the match that starts earliest; if two matches start at the same index,
                        // prefer the longer match so we don't accidentally pick a short substring
                        // like "两天" when a longer "两天半" also matches at the same position.
                        if r.lowerBound < earliestStart || (r.lowerBound == earliestStart && (earliestRange == nil || r.upperBound > earliestRange!.upperBound)) {
                            earliestStart = r.lowerBound; earliestRange = r; earliestColor = rule.color
                        }
                    }
                }
            }
            if let pattern = rule.pattern {
                if let r = remaining.range(of: pattern, options: .regularExpression) {
                    if r.lowerBound < earliestStart || (r.lowerBound == earliestStart && (earliestRange == nil || r.upperBound > earliestRange!.upperBound)) {
                        earliestStart = r.lowerBound; earliestRange = r; earliestColor = rule.color
                    }
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
