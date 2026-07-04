import SwiftUI
import PhotosUI

// MARK: - Recipe Detail (spec: read-only, colored text, tags)

struct RecipeDetailView: View {
    @Environment(RecipeStore.self) private var store
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
        .background(Color.bgSecondary)
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left").font(.bodyText.weight(.semibold)).foregroundColor(.white)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Edit Recipe", systemImage: "pencil") { showEdit = true }
                    Button("Edit Tags", systemImage: "tag") { }
                    Divider()
                    Button("Delete Recipe", systemImage: "trash", role: .destructive) { showDelete = true }
                } label: {
                    Image(systemName: "ellipsis").font(.title2).foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showGroceries) { AddToGroceriesSheet(recipe: recipe) }
        .sheet(isPresented: $showEdit) { RecipeEditView(existingRecipe: recipe) }
        .alert("Delete Recipe", isPresented: $showDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { store.delete(recipe); dismiss() }
        } message: { Text("Delete \"\(recipe.name)\"?") }
    }

    // MARK: Hero

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            if let url = store.photoURL(for: recipe), let img = UIImage(contentsOfFile: url.path) {
                Image(uiImage: img).resizable().scaledToFill().frame(height: 360).clipped()
            } else {
                LinearGradient(colors: [.brandBlue.opacity(0.3), .brandBlue.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing).frame(height: 360)
            }
            LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .bottom, endPoint: .center).frame(height: 360)

            VStack(alignment: .leading, spacing: 8) {
                Text(recipe.name).font(.title1).foregroundColor(.white)
            }
            .padding(.leading, 20).padding(.bottom, 20)
        }
    }

    // MARK: Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Start (green per spec)
            Button(action: { }) {
                Label("Start", systemImage: "play.fill")
                    .font(.bodyText.weight(.semibold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 48).background(Color.accentGreen).clipShape(Capsule())
            }

            // Basket
            Button(action: { showGroceries = true }) {
                Image(systemName: "basket").font(.title2).foregroundColor(.brandBlue)
                    .frame(width: 48, height: 48).background(Circle().fill(Color.cardBg).stroke(Color.dividerColor, lineWidth: 1))
            }

            // Share
            Button(action: { }) {
                Image(systemName: "square.and.arrow.up").font(.title2).foregroundColor(.brandBlue)
                    .frame(width: 48, height: 48).background(Circle().fill(Color.cardBg).stroke(Color.dividerColor, lineWidth: 1))
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
    }

    // MARK: Info Bar

    private var infoBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Text("👥").font(.subheadline)
                Text("\(displayServings)").font(.calloutText).foregroundColor(.textSecondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 6).background(Color.cardBg).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.dividerColor, lineWidth: 1))

            if recipe.totalTime > 0 {
                HStack(spacing: 6) {
                    Text("⏱").font(.subheadline)
                    Text("Prep \(timeStr(recipe.prepTime)) · Cook \(timeStr(recipe.cookTime))").font(.calloutText).foregroundColor(.textSecondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 6).background(Color.cardBg).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.dividerColor, lineWidth: 1))
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 16)
    }

    // MARK: Ingredients

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title and Scale outside the rounded rect
            HStack {
                Text("Ingredients").font(.title2)
                Spacer()
                if showScale {
                    Button(action: {
                        withAnimation {
                            // Commit the scale: scale ingredient amounts + update servings
                            var updated = recipe
                            let scale = Double(displayServings) / Double(recipe.servings)
                            let fuzzy = ["适量", "少许", "少量", "若干"]
                            updated.ingredients = updated.ingredients.map { ing in
                                guard !fuzzy.contains(ing.unit) else { return ing }
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
                    }) {
                        Text("\(displayServings) servings").font(.calloutText).foregroundColor(.brandBlue)
                            .padding(.horizontal, 12).padding(.vertical, 6).background(Color.brandBlueLight).clipShape(Capsule())
                    }
                } else {
                    Button(action: { withAnimation { showScale = true; scaleServings = recipe.servings } }) {
                        Text("Scale").font(.calloutText).foregroundColor(.brandBlue)
                            .padding(.horizontal, 12).padding(.vertical, 6).background(Color.brandBlueLight).clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 20)

            // Scale slider (video-timeline style)
            if showScale {
                HStack(spacing: 12) {
                    Slider(value: Binding(get: { Double(displayServings) }, set: { scaleServings = Int($0) }), in: 1...20, step: 1)
                        .tint(.brandBlue)
                    Text("\(displayServings) 份").font(.bodyText.weight(.semibold)).foregroundColor(.brandBlue)
                        .frame(width: 60, alignment: .trailing)
                }
                .padding(.horizontal, 20).padding(.vertical, 4)
            }

            // All ingredients in ONE rounded rect, left-aligned with blue quantifiers
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.element.id) { i, ing in
                    let amountUnit = showScale
                        ? recipe.scaledAmount(for: ing, targetServings: displayServings)
                        : ing.amountWithUnit
                    ingredientDisplayLine(name: ing.name, amountUnit: amountUnit)
                }
            }
            .padding(16)
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 8)
    }

    private func ingredientDisplayLine(name: String, amountUnit: String) -> some View {
        HStack {
            // Left-aligned: quantifier blue, rest black
            Text(amountUnit)
                .font(.bodyText.weight(.semibold))
                .foregroundColor(.brandBlue) +
            Text("  \(name)")
                .font(.bodyText)
                .foregroundColor(.black)
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

                    coloredText(step.description)
                        .font(.bodyText).lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(Color.bgPrimary, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 20)
    }

    private func coloredText(_ text: String) -> Text {
        var result = Text("")
        var remaining = text
        let sortedIng = recipe.ingredients.sorted { $0.name.count > $1.name.count }

        while !remaining.isEmpty {
            var matched = false
            // Ingredients → blue
            for ing in sortedIng {
                if let r = remaining.range(of: ing.name, options: .caseInsensitive) {
                    let before = String(remaining[remaining.startIndex..<r.lowerBound])
                    if !before.isEmpty { result = result + Text(before).foregroundColor(.black) }
                    result = result + Text(String(remaining[r])).foregroundColor(.brandBlue).bold()
                    remaining = String(remaining[r.upperBound...])
                    matched = true; break
                }
            }
            if matched { continue }

            // Temperature → orange (#\d+\s*°[FC]#)
            if let r = remaining.range(of: #"\d+\s*(°[FC]|度)"#, options: .regularExpression) {
                let before = String(remaining[remaining.startIndex..<r.lowerBound])
                if !before.isEmpty { result = result + Text(before).foregroundColor(.black) }
                result = result + Text(String(remaining[r])).foregroundColor(.accentOrange).fontWeight(.bold)
                remaining = String(remaining[r.upperBound...])
                continue
            }

            // Time → red (#\d+\s*(min|minutes|mins|分钟|秒|hour|hours)#)
            if let r = remaining.range(of: #"\d+\s*(min(ute)?s?|mins|分钟|秒|hour(s)?)"#, options: .regularExpression) {
                let before = String(remaining[remaining.startIndex..<r.lowerBound])
                if !before.isEmpty { result = result + Text(before).foregroundColor(.black) }
                result = result + Text(String(remaining[r])).foregroundColor(.accentRed).fontWeight(.bold)
                remaining = String(remaining[r.upperBound...])
                continue
            }

            result = result + Text(String(remaining.first!)).foregroundColor(.black)
            remaining = String(remaining.dropFirst())
        }
        return result
    }

    // MARK: Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags").font(.title2)
                .padding(.horizontal, 20).padding(.top, 12)

            HStack(spacing: 8) {
                // Sample tags
                Text("#dessert").font(.calloutText).foregroundColor(.tagText)
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .background(Color.tagBg).clipShape(Capsule())
                Text("#baking").font(.calloutText).foregroundColor(.tagText)
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .background(Color.tagBg).clipShape(Capsule())
            }
            .padding(.horizontal, 20)

            Text("Shared by RecipeSlate ❤️")
                .font(.calloutText).foregroundColor(.textTertiary)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
        }
        .padding(.bottom, 20)
    }

    private func timeStr(_ t: TimeInterval) -> String {
        let m = Int(t / 60); return m > 0 ? "\(m)min" : "0min"
    }
}

// MARK: - Add to Groceries Sheet (spec)

private struct AddToGroceriesSheet: View {
    @Environment(\.dismiss) private var dismiss
    var recipe: Recipe
    @State private var selected = Set<String>()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    ForEach(recipe.ingredients) { ing in
                        HStack(spacing: 12) {
                            Button(action: {
                                if selected.contains(ing.id) { selected.remove(ing.id) }
                                else { selected.insert(ing.id) }
                            }) {
                                Image(systemName: selected.contains(ing.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title2).foregroundColor(selected.contains(ing.id) ? .brandBlue : .textSecondary)
                            }
                            .buttonStyle(.plain)

                            Text(ing.displayString)
                                .font(.bodyText)
                            + Text("")

                            Spacer()

                            Button(action: { selected.remove(ing.id) }) {
                                Image(systemName: "xmark.circle.fill").font(.title3).foregroundColor(.accentRed)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(16)
                        .background(Color.bgPrimary, in: RoundedRectangle(cornerRadius: 12))
                        .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowSeparator(.hidden).listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain).background(Color.bgSecondary)
                .navigationTitle("Add to Groceries")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                            .font(.bodyText.weight(.medium)).foregroundColor(.black)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color.cardBg).clipShape(Capsule())
                    }
                }

                // Bottom bar
                HStack(spacing: 12) {
                    Button(selected.count == recipe.ingredients.count ? "Deselect All" : "Select All") {
                        if selected.count == recipe.ingredients.count { selected.removeAll() }
                        else { selected = Set(recipe.ingredients.map(\.id)) }
                    }
                    .font(.bodyText.weight(.semibold)).foregroundColor(.brandBlue)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(Color.brandBlueLight).clipShape(Capsule())

                    Button("Add \(selected.count) Items") {
                        dismiss()
                    }
                    .font(.bodyText.weight(.semibold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(Color.brandBlue).clipShape(Capsule())
                    .disabled(selected.isEmpty)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(.regularMaterial)
            }
        }
    }
}
