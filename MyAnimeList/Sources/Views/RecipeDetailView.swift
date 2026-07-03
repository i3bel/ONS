import SwiftUI
import PhotosUI

// MARK: - Recipe Detail (read-only)

struct RecipeDetailView: View {
    @Environment(RecipeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var recipe: Recipe

    @State private var showGroceries = false
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var scaleServings: Int? = nil
    @State private var showScale = false
    @State private var showStartConfirm = false

    private var displayServings: Int { scaleServings ?? recipe.servings }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Cover
                coverSection
                // Action buttons
                actionButtons
                // Info bar
                infoBar
                // Ingredients
                ingredientsSection
                // Method
                methodSection
            }
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit Recipe", systemImage: "pencil") { showEdit = true }
                    Button("Edit Tags", systemImage: "tag") { }
                    Divider()
                    Button("Delete Recipe", systemImage: "trash", role: .destructive) { showDeleteConfirm = true }
                } label: {
                    Image(systemName: "ellipsis").font(.title2).frame(width: 20, height: 20).padding(10)
                }
                .buttonStyle(.glass).buttonBorderShape(.circle)
            }
        }
        .sheet(isPresented: $showGroceries) { AddToGroceriesSheet(recipe: recipe) }
        .sheet(isPresented: $showEdit) { RecipeEditView(existingRecipe: recipe) }
        .alert("删除食谱", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { store.delete(recipe); dismiss() }
        } message: { Text("确定删除「\(recipe.name)」？") }
    }

    // MARK: Cover

    private var coverSection: some View {
        ZStack(alignment: .bottomLeading) {
            if let url = store.photoURL(for: recipe), let img = UIImage(contentsOfFile: url.path) {
                Image(uiImage: img).resizable().scaledToFill().frame(height: 260).clipped()
            } else {
                LinearGradient(colors: [.orange.opacity(0.5), .red.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing).frame(height: 260)
            }
            LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .bottom, endPoint: .center).frame(height: 260)
            Text(recipe.name)
                .font(.largeTitle.weight(.bold)).foregroundStyle(.white)
                .padding(.leading, 20).padding(.bottom, 16)
        }
    }

    // MARK: Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: { showStartConfirm = true }) {
                Label("Start", systemImage: "play.fill")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent).tint(.orange).buttonBorderShape(.capsule)

            Button(action: { showGroceries = true }) {
                Image(systemName: "basket").font(.title2).frame(width: 20, height: 20).padding(14)
            }
            .buttonStyle(.bordered).buttonBorderShape(.circle)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
    }

    // MARK: Info Bar

    private var infoBar: some View {
        HStack(spacing: 20) {
            Label("\(recipe.servings) 人份", systemImage: "person.2")
            if recipe.totalTime > 0 {
                Label(timeStr(recipe.totalTime), systemImage: "clock")
            }
            Spacer()
        }
        .font(.subheadline).foregroundStyle(.secondary)
        .padding(.horizontal, 20).padding(.bottom, 12)
    }

    // MARK: Ingredients

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Ingredients").font(.title3.weight(.bold))
                Spacer()
                Button(action: { withAnimation { showScale.toggle() } }) {
                    HStack(spacing: 4) {
                        Image(systemName: "scale.3d")
                        Text("Scale").font(.subheadline)
                    }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 8)

            if showScale {
                HStack {
                    Text("份量:")
                    Stepper("\(displayServings) 人份", value: Binding(get: { displayServings }, set: { scaleServings = $0 }), in: 1...20)
                        .labelsHidden()
                    Text("\(displayServings) 人份").font(.subheadline.monospacedDigit())
                }
                .padding(.horizontal, 20).padding(.bottom, 8)
            }

            ForEach(recipe.ingredients) { ing in
                ingredientRow(ing)
                Divider().padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private func ingredientRow(_ ing: Ingredient) -> some View {
        HStack {
            Text(ing.name).font(.body)
            Spacer()
            let display = showScale ? recipe.scaledAmount(for: ing, targetServings: displayServings) : "\(Int(ing.amount)) \(ing.unit)"
            // Highlight the numeric+unit part
            Text(display)
                .font(.body.weight(.semibold))
                .foregroundStyle(.orange)
        }
        .padding(.horizontal, 20).padding(.vertical, 6)
    }

    // MARK: Method

    private var methodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Method").font(.title3.weight(.bold))
                .padding(.horizontal, 20).padding(.top, 16)

            ForEach(Array(recipe.steps.enumerated()), id: \.element.id) { i, step in
                stepCard(i: i, step: step)
            }
        }
        .padding(.bottom, 20)
    }

    private func stepCard(i: Int, step: CookingStep) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Circle number
            ZStack {
                Circle().fill(Color.blue).frame(width: 28, height: 28)
                Text("\(i + 1)").font(.callout.weight(.bold)).foregroundStyle(.white)
            }

            // Colored text
            coloredText(step.description)
                .font(.body).lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    private func coloredText(_ text: String) -> Text {
        // Simple approach: scan for ingredients (blue), temperatures (orange), times (red)
        var result = Text("")
        var remaining = text
        let sortedIng = recipe.ingredients.sorted { $0.name.count > $1.name.count }

        while !remaining.isEmpty {
            var matched = false
            // Check ingredients first (blue)
            for ing in sortedIng {
                if let r = remaining.range(of: ing.name, options: .caseInsensitive) {
                    let before = String(remaining[remaining.startIndex..<r.lowerBound])
                    if !before.isEmpty { result = result + coloredText(before) }
                    result = result + Text(String(remaining[r])).foregroundColor(.blue).bold()
                    remaining = String(remaining[r.upperBound...])
                    matched = true; break
                }
            }
            if matched { continue }

            // Check temperature (°F/°C)
            if let r = remaining.range(of: #"\d+\s*°[FC]"#, options: .regularExpression) {
                let before = String(remaining[remaining.startIndex..<r.lowerBound])
                if !before.isEmpty { result = result + coloredText(before) }
                result = result + Text(String(remaining[r])).foregroundColor(.orange).fontWeight(.bold)
                remaining = String(remaining[r.upperBound...])
                continue
            }

            // Check time (X minutes/X seconds)
            if let r = remaining.range(of: #"\d+\s*[分钟秒小时]"#, options: .regularExpression) {
                let before = String(remaining[remaining.startIndex..<r.lowerBound])
                if !before.isEmpty { result = result + coloredText(before) }
                result = result + Text(String(remaining[r])).foregroundColor(.red).fontWeight(.bold)
                remaining = String(remaining[r.upperBound...])
                continue
            }

            result = result + Text(String(remaining.first!))
            remaining = String(remaining.dropFirst())
        }
        return result
    }

    private func plainText(_ text: String) -> Text {
        Text(text).foregroundColor(.primary)
    }

    private func timeStr(_ t: TimeInterval) -> String {
        let m = Int(t / 60)
        if m >= 60 { return "\(m/60)h \(m%60)m" }
        return "\(m)分钟"
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
            List {
                ForEach(recipe.ingredients) { ing in
                    HStack(spacing: 10) {
                        Button(action: {
                            if selected.contains(ing.id) { selected.remove(ing.id) }
                            else { selected.insert(ing.id) }
                        }) {
                            Image(systemName: selected.contains(ing.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title3).foregroundStyle(selected.contains(ing.id) ? .blue : .secondary)
                        }
                        .buttonStyle(.plain)

                        Text(ing.displayString)
                            .font(.body)
                        // Highlight amount+unit
                            .foregroundStyle(.primary)
                        +
                        Text("")
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { selected.remove(ing.id) } label: { Image(systemName: "trash") }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Add to Groceries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add \(selected.count) items") {
                        // Will integrate with Tab 3 later
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Button(selected.count == recipe.ingredients.count ? "Deselect All" : "Select All") {
                        if selected.count == recipe.ingredients.count { selected.removeAll() }
                        else { selected = Set(recipe.ingredients.map(\.id)) }
                    }
                    .font(.subheadline.weight(.semibold))

                    Spacer()

                    Button("Add \(selected.count) items") {
                        dismiss()
                    }
                    .font(.subheadline.weight(.bold))
                    .disabled(selected.isEmpty)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(.thinMaterial)
            }
        }
    }
}
