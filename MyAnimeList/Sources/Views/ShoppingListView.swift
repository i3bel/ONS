import SwiftUI
import EventKit

struct ShoppingListView: View {
    @Environment(RecipeStore.self) private var store
    @State private var completed = Set<String>()
    @State private var showAlert = false
    @State private var alertMsg = ""

    private var mergedItems: [(String, Double, String, String)] {
        var dict: [String: (Double, String, String)] = [:] // name_unit: (total, unit, sources)
        for r in store.recipes {
            for ing in r.ingredients {
                let key = "\(ing.name.lowercased())_\(ing.unit)"
                if var existing = dict[key] {
                    existing.0 += ing.amount
                    dict[key] = existing
                } else {
                    dict[key] = (ing.amount, ing.unit, r.name)
                }
            }
        }
        return dict.map { (name: String($0.key.split(separator: "_")[0]), amount: $0.value.0, unit: $0.value.1, source: $0.value.2) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List {
                if mergedItems.isEmpty {
                    ContentUnavailableView("没有食材", systemImage: "cart", description: Text("食谱中的食材会自动出现在这里"))
                        .listRowBackground(Color.clear)
                }
                ForEach(mergedItems, id: \.0) { (name, amount, unit, _) in
                    HStack(spacing: 10) {
                        Button(action: { toggle(name) }) {
                            Image(systemName: completed.contains(name) ? "checkmark.circle.fill" : "circle")
                                .font(.title3).foregroundStyle(completed.contains(name) ? .green : .secondary)
                        }
                        .buttonStyle(.plain)

                        Text(name).font(.body).strikethrough(completed.contains(name))
                        Spacer()
                        Text(formatAmount(amount)).font(.body.weight(.semibold)).foregroundStyle(.orange)
                        Text(unit).font(.footnote).foregroundStyle(.secondary)
                    }
                    .opacity(completed.contains(name) ? 0.5 : 1)
                }
            }
            .listStyle(.plain)
            .navigationTitle("采购清单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: syncToReminders) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                            Text("同步").font(.footnote)
                        }
                    }
                }
            }
            .alert(alertMsg, isPresented: $showAlert) { Button("好的") {} }
        }
    }

    private func toggle(_ name: String) {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        withAnimation { if completed.contains(name) { completed.remove(name) } else { completed.insert(name) } }
    }

    private func syncToReminders() {
        Task {
            let ek = EKEventStore()
            do {
                try await ek.requestFullAccessToReminders()
                let cal = ek.defaultCalendarForNewReminders()
                for (name, amount, unit, _) in mergedItems where !completed.contains(name) {
                    let r = EKReminder(eventStore: ek)
                    r.title = name; r.notes = "\(formatAmount(amount)) \(unit)"
                    r.calendar = cal; try ek.save(r, commit: true)
                }
                await MainActor.run { alertMsg = "已同步到提醒事项"; showAlert = true }
            } catch {
                await MainActor.run { alertMsg = "同步失败：\(error.localizedDescription)"; showAlert = true }
            }
        }
    }

    private func formatAmount(_ a: Double) -> String {
        a == floor(a) ? String(format: "%.0f", a) : String(format: "%.1f", a)
    }
}
