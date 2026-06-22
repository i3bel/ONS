import SwiftUI
import PhotosUI

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
                .navigationTitle("详细信息")
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
        VStack(spacing: 8) {
            // Removed cover image — show compact header
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(binding.wrappedValue.scene) 场 - \(binding.wrappedValue.clip) 镜 - \(binding.wrappedValue.take) 次")
                        .font(.title.bold())
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    HStack(spacing: 8) {
                        VlogSlateStatusBadge(status: binding.wrappedValue.status)
                        Text(binding.wrappedValue.timestamp.formatted(date: .numeric, time: .standard))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Favorite toggle remains available in header
                Button(action: { binding.isFavorite.wrappedValue.toggle() }) {
                    Image(systemName: binding.isFavorite.wrappedValue ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(binding.isFavorite.wrappedValue ? .pink : .primary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                VlogSlateStatCard(
                    title: "场",
                    value: "\(binding.wrappedValue.scene)",
                    systemImage: "rectangle.stack.fill"
                )
                VlogSlateStatCard(
                    title: "镜",
                    value: "\(binding.wrappedValue.clip)",
                    systemImage: "camera.aperture",
                    tint: .cyan
                )
                VlogSlateStatCard(
                    title: "次",
                    value: "\(binding.wrappedValue.take)",
                    systemImage: "viewfinder",
                    tint: .orange
                )
            }
        }
    }

    // Photo picker state for selecting a scene thumbnail
    @State private var showPhotoPicker = false
    @State private var photoSelection: PhotosPickerItem? = nil
    @State private var showCamera = false
    @State private var showActionSheet = false

    // Helper to present picker and store selection
    private func photoPickerButton(for binding: Binding<FootageItem>) -> some View {
        HStack(spacing: 12) {
            Button("更换场景缩略图") {
                showActionSheet = true
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.blue)
            .frame(maxWidth: .infinity)
            .confirmationDialog("更换场景缩略图", isPresented: $showActionSheet) {
                Button("从相册选择") {
                    photoSelection = nil
                    showPhotoPicker = true
                }
                Button("拍照") {
                    showCamera = true
                }
                if store.thumbnailURL(forScene: binding.wrappedValue.scene) != nil {
                    Button("删除缩略图", role: .destructive) {
                        removeSceneThumbnail(scene: binding.wrappedValue.scene)
                    }
                }
                Button("取消", role: .cancel) {}
            }

            .photosPicker(isPresented: $showPhotoPicker, selection: $photoSelection, matching: .images)
            .onChange(of: photoSelection) { _old, newItem in
                guard let item = newItem else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        saveSceneThumbnail(data: data, scene: binding.wrappedValue.scene)
                    }
                }
            }

            // Camera sheet
            .sheet(isPresented: $showCamera) {
                UIImagePicker(source: .camera) { image in
                    // Compress to JPEG
                    if let data = image.jpegData(compressionQuality: 0.8) {
                        saveSceneThumbnail(data: data, scene: binding.wrappedValue.scene)
                    }
                    showCamera = false
                }
            }
        }
    }

    private func saveSceneThumbnail(data: Data, scene: Int) {
        // Save file into same directory as footage.json
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = supportDirectory.appendingPathComponent("VlogSlate", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filename = "scene_\(scene)_thumb.jpg"
        let url = dir.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: [.atomic])
            store.sceneThumbnails[scene] = filename
            // force save
            store.replaceItems(store.items, currentScene: store.currentScene)
        } catch {
            print("Failed to save thumbnail: \(error)")
        }
    }

    private func removeSceneThumbnail(scene: Int) {
        if let filename = store.sceneThumbnails[scene] {
            let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let url = supportDirectory.appendingPathComponent("VlogSlate", isDirectory: true).appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: url)
        }
        store.sceneThumbnails.removeValue(forKey: scene)
        store.replaceItems(store.items, currentScene: store.currentScene)
    }

    private func notesPanel(for binding: Binding<FootageItem>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("备注", systemImage: "text.alignleft")
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
            photoPickerButton(for: binding)

            HStack(spacing: 12) {
                Button {
                    binding.status.wrappedValue = .good
                } label: {
                    Label("完美", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(binding.status.wrappedValue == .good ? .green : .secondary)

                Button {
                    binding.status.wrappedValue = .backup
                } label: {
                    Label("备用", systemImage: "rectangle.stack.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(binding.status.wrappedValue == .backup ? .yellow : .secondary)

                Button {
                    binding.status.wrappedValue = .bad
                } label: {
                    Label("废镜", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(binding.status.wrappedValue == .bad ? .red : .secondary)
            }
        }
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}


