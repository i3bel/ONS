import SwiftUI

struct FootageDetailView: View {
    @EnvironmentObject var store: VlogSlateStore
    @Environment(\.dismiss) private var dismiss
    @State private var itemId: String

    init(item: FootageItemBinding) {
        _itemId = State(initialValue: item.id)
    }

    var body: some View {
        NavigationStack {
            if let idx = store.items.firstIndex(where: { $0.id == itemId }) {
                let binding = $store.items[idx]

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header(for: binding)
                        notesPanel(for: binding)
                        ratingPanel(for: binding)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 20)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Take Detail")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            } else {
                ContentUnavailableView("Item not found", systemImage: "questionmark.folder")
            }
        }
    }

    private func header(for binding: Binding<FootageItem>) -> some View {
        VStack(spacing: 18) {
            VlogSlatePosterBlock(scene: binding.wrappedValue.scene, take: binding.wrappedValue.take, style: .hero)
                .frame(maxWidth: .infinity)
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .overlay(alignment: .topTrailing) {
                    Button(action: { binding.isFavorite.wrappedValue.toggle() }) {
                        Image(systemName: binding.isFavorite.wrappedValue ? "heart.fill" : "heart")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(binding.isFavorite.wrappedValue ? .pink : .white.opacity(0.9))
                            .frame(width: 34, height: 34)
                    }
                    .padding(12)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text("Scene \(binding.wrappedValue.scene) - Take \(binding.wrappedValue.take)")
                    .font(.largeTitle.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                HStack(spacing: 8) {
                    VlogSlateStatusBadge(status: binding.wrappedValue.status)
                    Text(binding.wrappedValue.timestamp.formatted(date: .numeric, time: .standard))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                VlogSlateStatCard(
                    title: "Scene",
                    value: "\(binding.wrappedValue.scene)",
                    systemImage: "rectangle.stack.fill"
                )
                VlogSlateStatCard(
                    title: "Take",
                    value: "\(binding.wrappedValue.take)",
                    systemImage: "viewfinder",
                    tint: .cyan
                )
            }
        }
    }

    private func notesPanel(for binding: Binding<FootageItem>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Footage Notes", systemImage: "text.alignleft")
                .font(.headline)
                .foregroundStyle(.secondary)

            TextEditor(text: Binding(get: { binding.wrappedValue.notes }, set: { binding.wrappedValue.notes = $0 }))
                .font(.title3)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 260)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }

    private func ratingPanel(for binding: Binding<FootageItem>) -> some View {
        VStack(spacing: 12) {
            Button(action: { binding.isFavorite.wrappedValue.toggle() }) {
                Label("核心镜头", systemImage: binding.isFavorite.wrappedValue ? "heart.fill" : "heart")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(binding.isFavorite.wrappedValue ? .pink : .secondary)

            HStack(spacing: 12) {
                StatusButton(title: "完美", color: .green, isSelected: binding.status.wrappedValue == .good) {
                    binding.status.wrappedValue = .good
                }
                StatusButton(title: "备用", color: .yellow, isSelected: binding.status.wrappedValue == .backup) {
                    binding.status.wrappedValue = .backup
                }
                StatusButton(title: "废镜", color: .red, isSelected: binding.status.wrappedValue == .bad) {
                    binding.status.wrappedValue = .bad
                }
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct StatusButton: View {
    var title: String
    var color: Color
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .tint(isSelected ? color : .secondary)
    }
}
