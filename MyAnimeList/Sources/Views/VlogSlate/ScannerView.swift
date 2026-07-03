//
//  ScannerView.swift
//  VlogSlate
//
//  Created by OpenAI Codex on behalf of hole on 2026/6/20.
//

@preconcurrency import AVFoundation
import SwiftUI

struct ScannerView: View {
    @Environment(VlogSlateStore.self) private var store
    @State private var selectedItem: FootageItem?
    @State private var scannedCode: String?
    @State private var isScanning = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if isScanning {
                    VlogQRCodeScannerView { code in
                        handleScannedCode(code)
                    }
                    .ignoresSafeArea(edges: .bottom)
                } else {
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("搜索使用示例")
                                .font(.title2.weight(.bold))
                                .padding(.bottom, 4)

                            SearchTipGroup(title: "精准定位") {
                                SearchTip(query: "S1C2", desc: "第1场，第2个镜头号的所有镜头")
                                SearchTip(query: "S1C2T3", desc: "第1场，第2个镜头，第3次拍摄")
                            }

                            SearchTipGroup(title: "范围筛选") {
                                SearchTip(query: "S1-3", desc: "第1到3场的所有镜头")
                                SearchTip(query: "C>3", desc: "镜头号大于3的镜头")
                                SearchTip(query: "T>1", desc: "所有重拍镜头（Take大于1）")
                            }

                            SearchTipGroup(title: "组合搜索") {
                                SearchTip(query: "S2 C>3", desc: "第2场里镜头号大于3的镜头")
                                SearchTip(query: "S1-3 C2 T>1", desc: "第1到3场，第2镜头号的重拍镜头")
                            }

                            SearchTipGroup(title: "状态筛选") {
                                SearchTip(query: "完美", desc: "所有完美镜头")
                                SearchTip(query: "备用", desc: "所有备用镜头")
                                SearchTip(query: "废镜", desc: "所有废镜")
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 24)
                        .padding(.bottom, 100)
                    }
                }

                VStack(spacing: 16) {
                    if isScanning {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("扫描素材画面中的二维码", systemImage: "qrcode.viewfinder")
                                .font(.headline)
                            Text(scannedCode ?? "等待二维码")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .monospaced()
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(.white.opacity(0.12), lineWidth: 1)
                        }
                    }

                    Button {
                        withAnimation(.spring) {
                            isScanning.toggle()
                            if !isScanning { scannedCode = nil }
                        }
                    } label: {
                        Label(isScanning ? "停止扫码" : "开始扫码",
                              systemImage: isScanning ? "stop.circle" : "qrcode.viewfinder")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(isScanning ? .red : .blue)
                }
                .padding()
            }
            .navigationTitle("")
            .sheet(item: $selectedItem) { item in
                FootageDetailView(item: FootageItemBinding(id: item.id))
            }
        }
    }
    private func handleScannedCode(_ code: String) {
        scannedCode = code

        let decodedID: String?
        if let data = code.data(using: .utf8),
           let payload = try? JSONDecoder.vlogSlate.decode(VlogSlatePayload.self, from: data) {
            decodedID = payload.id
        } else {
            decodedID = code
        }

        guard let decodedID,
              selectedItem?.id != decodedID,
              let item = store.items.first(where: { $0.id == decodedID })
        else { return }

        selectedItem = item
    }
}

private struct VlogQRCodeScannerView: UIViewControllerRepresentable {
    var onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> VlogQRCodeScannerViewController {
        let controller = VlogQRCodeScannerViewController()
        controller.onCodeScanned = onCodeScanned
        return controller
    }

    func updateUIViewController(_ uiViewController: VlogQRCodeScannerViewController, context: Context) {}
}

private final class VlogQRCodeScannerViewController: UIViewController {
    var onCodeScanned: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning {
            let captureSession = session
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            let captureSession = session
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.stopRunning()
            }
        }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }

        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)
        self.previewLayer = previewLayer
    }

}

extension VlogQRCodeScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let value = object.stringValue
        else { return }

        Task { @MainActor in
            onCodeScanned?(value)
        }
    }
}

private struct SearchTipGroup<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                content()
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct SearchTip: View {
    var query: String
    var desc: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(query)
                .font(.system(.callout, design: .monospaced).weight(.semibold))
                .foregroundStyle(.cyan)
                .frame(minWidth: 80, alignment: .leading)
            Text(desc)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
