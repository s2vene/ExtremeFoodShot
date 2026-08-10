import SwiftUI

struct ContentView: View {
    @StateObject private var model = ExperimentViewModel()
    @State private var isExperimentActive = false
    @State private var showTuning = false

    var body: some View {
        ZStack {
            CameraPreview(session: model.camera.session)
                .ignoresSafeArea()

            LinearGradient(
                colors: [.black.opacity(0.55), .clear, .black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                header
                Spacer()
                diagnostics
                controls
            }
            .padding()
        }
        .foregroundStyle(.white)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .sheet(isPresented: $model.showResults) {
            ResultsView(camera: model.camera)
        }
        .sheet(isPresented: $showTuning) {
            TuningView(model: model, motion: model.motion)
        }
        .alert("카메라 오류", isPresented: Binding(
            get: { model.camera.errorMessage != nil },
            set: { if !$0 { model.camera.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { model.camera.errorMessage = nil }
        } message: {
            Text(model.camera.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("EXTREME FOOD SHOT").font(.caption.bold())
                    Text(model.statusMessage).font(.headline)
                }
                Spacer()
                Button {
                    showTuning = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .frame(width: 32, height: 32)
                }
                Label("\(model.camera.candidates.count)/\(model.maximumCandidates)", systemImage: "photo.stack")
                    .font(.subheadline.monospacedDigit())
            }

            if model.camera.authorizationDenied {
                Label("설정에서 카메라 권한을 허용해 주세요.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
            }
            if !model.motion.isAvailable {
                Label("이 기기에서 Device Motion을 사용할 수 없습니다.", systemImage: "waveform.path.ecg")
                    .foregroundStyle(.yellow)
            }
        }
        .padding(14)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
    }

    private var diagnostics: some View {
        VStack(spacing: 10) {
            HStack {
                metric("상태", model.motion.snapshot.phase.rawValue)
                metric("축 가속", String(format: "%.2fg", model.motion.snapshot.axialAcceleration))
                metric("회전", String(format: "%.2f", model.motion.snapshot.rotationMagnitude))
                metric("밝기", "\(Int(model.camera.frameMetrics.brightness * 100))%")
            }
            MotionGraph(samples: model.motion.axialHistory, threshold: model.motion.triggerThreshold)
        }
        .padding(12)
        .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 16))
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Picker("조명", selection: $model.lightingMode) {
                ForEach(LightingMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .disabled(isExperimentActive)

            Toggle("움직임 전환점 자동 촬영", isOn: $model.automaticCapture)
                .tint(.orange)

            HStack(spacing: 14) {
                Button {
                    model.manualCapture()
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.title2)
                        .frame(width: 54, height: 54)
                        .background(.white.opacity(0.2), in: Circle())
                }

                Button {
                    isExperimentActive.toggle()
                    if isExperimentActive { model.beginExperiment() }
                    else { model.finishExperiment() }
                } label: {
                    Label(
                        isExperimentActive ? "촬영 완료" : "테스트 시작",
                        systemImage: isExperimentActive ? "stop.fill" : "figure.wave"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isExperimentActive ? Color.red : Color.orange, in: Capsule())
                }

                Button {
                    model.showResults = true
                } label: {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title2)
                        .frame(width: 54, height: 54)
                        .background(.white.opacity(0.2), in: Circle())
                }
                .disabled(model.camera.candidates.isEmpty)
            }
        }
        .padding(14)
        .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 18))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.bold().monospacedDigit()).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
