//
//  ScannerView.swift
//  AniShelf
//
//  Created by OpenAI Codex on behalf of hole on 2026/6/20.
//

@preconcurrency import AVFoundation
import SwiftUI

struct ScannerView: View {
    @EnvironmentObject private var store: VlogSlateStore
    @State private var selectedItem: FootageItem?
    @State private var scannedCode: String?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VlogQRCodeScannerView { code in
                    handleScannedCode(code)
                }
                .ignoresSafeArea(edges: .bottom)

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
                .padding()
            }
            .navigationTitle("Scanner")
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
