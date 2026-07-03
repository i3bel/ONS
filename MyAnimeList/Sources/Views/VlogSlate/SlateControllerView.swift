import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct SlateControllerView: View {
    @Environment(VlogSlateStore.self) private var store
    @State private var showsFullScreenSlate = false
    @State private var fullScreenCountdown = 3
    @State private var countdownTask: Task<Void, Never>?

    private var currentPayload: VlogSlatePayload {
        store.payloadForCurrentSlate()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                controlCards
                qrPanel
                actionRow
            }
            .padding(.horizontal)
            .padding(.vertical, 20)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.large)
            .fullScreenCover(isPresented: $showsFullScreenSlate, onDismiss: cancelCountdown) {
                FullScreenSlateView(payload: currentPayload, countdown: fullScreenCountdown) {
                    finishFullScreenSlate()
                }
                .onAppear(perform: startCountdown)
            }
            .onDisappear(perform: cancelCountdown)
        }
    }

    private var controlCards: some View {
        HStack(spacing: 12) {
            SlateCounterCard(title: "场", value: $store.currentScene, systemImage: "rectangle.stack.fill")
            SlateCounterCard(title: "镜", value: $store.currentClip, systemImage: "camera.aperture", tint: .cyan)
        }
    }

    private var qrPanel: some View {
        VStack(spacing: 18) {
            QRWithLabelView(payload: currentPayload)
                .frame(maxWidth: 360)
                .aspectRatio(1, contentMode: .fit)
                .padding(18)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture {
                    presentFullScreenSlate()
                }

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    
                    Text("\(currentPayload.scene)")
                        .font(.title.weight(.black))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(currentPayload.scene)))
                        .animation(.bouncy, value: currentPayload.scene)
                    
                    Text("场")
                        .font(.title.weight(.black))

                    
                    Text("\(currentPayload.clip)")
                        .font(.title.weight(.black))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(currentPayload.clip)))
                        .animation(.bouncy, value: currentPayload.clip)
                    
                    Text("镜")
                        .font(.title.weight(.black))

                    Text("\(currentPayload.take)")
                        .font(.title.weight(.black))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(currentPayload.take)))
                        .animation(.bouncy, value: currentPayload.take)
                    
                    Text("次")
                        .font(.title.weight(.black))

                }
                Text(store.currentSlateID.prefix(8).uppercased())
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospaced()
                    .animation(.bouncy, value: store.currentSlateID)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .glassEffect(in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            VlogSlateCircleActionButton(systemImage: "minus") {
                store.currentClip = max(1, store.currentClip - 1)
            }
            .sensoryFeedback(.impact, trigger: store.currentClip)

            Button(action: store.addCurrentTake) {
                Label("拍板 + 插入", systemImage: "plus.rectangle.fill.on.rectangle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .sensoryFeedback(.success, trigger: store.items.count)

            VlogSlateCircleActionButton(systemImage: "plus") {
                store.currentClip += 1
            }
            .sensoryFeedback(.impact, trigger: store.currentClip)
        }
    }

    private func presentFullScreenSlate() {
        fullScreenCountdown = 3
        showsFullScreenSlate = true
    }

    private func startCountdown() {
        cancelCountdown()
        countdownTask = Task {
            for remaining in stride(from: 3, through: 1, by: -1) {
                await MainActor.run {
                    fullScreenCountdown = remaining
                }
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
            }
            await MainActor.run {
                finishFullScreenSlate()
            }
        }
    }

    private func finishFullScreenSlate() {
        cancelCountdown()
        store.addCurrentTake()
        showsFullScreenSlate = false
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
    }
}

struct QRWithLabelView: View {
    var payload: VlogSlatePayload
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        GeometryReader { g in
            ZStack {
                if let img = makeQR() {
                    Image(uiImage: img)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: g.size.width, height: g.size.height)
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.secondary.opacity(0.18))
                }
                HStack(spacing: 4) {
                    
                    Text("\(payload.scene)")
                        .font(.system(size: max(16, g.size.width * 0.10), weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(payload.scene)))
                        .animation(.bouncy, value: payload.scene)
                    
                    Text("场")
                        .font(.system(size: max(16, g.size.width * 0.10), weight: .black, design: .rounded))
                        .foregroundStyle(.black)

                    
                    Text("\(payload.clip)")
                        .font(.system(size: max(16, g.size.width * 0.10), weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(payload.clip)))
                        .animation(.bouncy, value: payload.clip)
                    
                    Text("镜")
                        .font(.system(size: max(16, g.size.width * 0.10), weight: .black, design: .rounded))
                        .foregroundStyle(.black)

                    
                    Text("\(payload.take)")
                        .font(.system(size: max(16, g.size.width * 0.10), weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(payload.take)))
                        .animation(.bouncy, value: payload.take)
                    
                    Text("次")
                        .font(.system(size: max(16, g.size.width * 0.10), weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(.black, lineWidth: 2)
                }
            }
        }
    }

    func makeQR() -> UIImage? {
        let data = Data(payload.qrString.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        if let output = filter.outputImage {
            let transformed = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
            if let cgimg = context.createCGImage(transformed, from: transformed.extent) {
                return UIImage(cgImage: cgimg)
            }
        }
        return nil
    }
}

private struct SlateCounterCard: View {
    var title: String
    @Binding var value: Int
    var systemImage: String
    var tint: Color = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(tint)
                Spacer()
                Stepper(title, value: $value, in: 1...999)
                    .labelsHidden()
                    .sensoryFeedback(.impact, trigger: value)
            }

            Text("\(value)")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
                .animation(.bouncy, value: value)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct FullScreenSlateView: View {
    var payload: VlogSlatePayload
    var countdown: Int
    var finish: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            VStack(spacing: 28) {
                QRWithLabelView(payload: payload)
                    .frame(maxWidth: 620, maxHeight: 620)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(.horizontal, 24)

                HStack(spacing: 8) {
                    Text("Scene")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(payload.scene)")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(payload.scene)))
                        .animation(.bouncy, value: payload.scene)

                    Text("- Clip")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(payload.clip)")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(payload.clip)))
                        .animation(.bouncy, value: payload.clip)

                    Text("- Take")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(payload.take)")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(payload.take)))
                        .animation(.bouncy, value: payload.take)
                }
                .minimumScaleFactor(0.45)
                .lineLimit(1)
                .padding(.horizontal)

                Text("\(countdown)")
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .foregroundColor(.yellow)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(countdown)))
                    .animation(.bouncy, value: countdown)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture(count: 2, perform: finish)

            Button(action: finish) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundColor(.white)
                    .padding()
            }
            .accessibilityLabel("Insert take")
        }
    }
}
