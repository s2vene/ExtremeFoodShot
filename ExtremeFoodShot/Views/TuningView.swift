import SwiftUI

struct TuningView: View {
    @ObservedObject var model: ExperimentViewModel
    @ObservedObject var motion: MotionAnalyzer
    @ObservedObject var camera: CameraService
    @Environment(\.dismiss) private var dismiss

    init(model: ExperimentViewModel, motion: MotionAnalyzer) {
        self.model = model
        self.motion = motion
        self.camera = model.camera
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("자동 촬영 판단") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("광축 가속 임계값")
                            Spacer()
                            Text(String(format: "%.2fg", motion.triggerThreshold))
                                .monospacedDigit()
                        }
                        Slider(value: $motion.triggerThreshold, in: 0.35...2.5, step: 0.05)
                    }

                    VStack(alignment: .leading) {
                        HStack {
                            Text("회전 허용치")
                            Spacer()
                            Text(String(format: "%.1f rad/s", motion.rotationLimit))
                                .monospacedDigit()
                        }
                        Slider(value: $motion.rotationLimit, in: 0.5...8, step: 0.1)
                    }

                    Stepper("최대 후보 \(model.maximumCandidates)장", value: $model.maximumCandidates, in: 3...15)
                }

                Section("렌즈와 촬영 처리") {
                    Picker("렌즈", selection: Binding(
                        get: { model.camera.selectedLens },
                        set: { model.camera.selectLens($0) }
                    )) {
                        ForEach(model.camera.availableLenses) { Text($0.rawValue).tag($0) }
                    }

                    Picker("촬영 품질", selection: $model.camera.captureQuality) {
                        ForEach(CaptureQualityPreset.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .onChange(of: model.camera.captureQuality) { _, _ in
                        model.camera.applyCameraTestSettings()
                    }

                    Toggle("Zero Shutter Lag", isOn: $model.camera.zeroShutterLagEnabled)
                        .disabled(!model.camera.supportsZeroShutterLag)
                        .onChange(of: model.camera.zeroShutterLagEnabled) { _, _ in
                            model.camera.applyCameraTestSettings()
                        }
                    Toggle("왜곡 보정", isOn: $model.camera.distortionCorrectionEnabled)
                        .disabled(!model.camera.supportsDistortionCorrection)
                        .onChange(of: model.camera.distortionCorrectionEnabled) { _, _ in
                            model.camera.applyCameraTestSettings()
                        }
                }

                Section("노출 · 초점 · 색상") {
                    Picker("노출시간", selection: $model.camera.exposurePreset) {
                        ForEach(ExposurePreset.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .onChange(of: model.camera.exposurePreset) { _, _ in
                        model.camera.applyCameraTestSettings()
                    }

                    Picker("초점", selection: $model.camera.focusPreset) {
                        ForEach(FocusPreset.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .onChange(of: model.camera.focusPreset) { _, _ in
                        model.camera.applyCameraTestSettings()
                    }

                    Picker("화이트밸런스", selection: $model.camera.whiteBalancePreset) {
                        ForEach(WhiteBalancePreset.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .onChange(of: model.camera.whiteBalancePreset) { _, _ in
                        model.camera.applyCameraTestSettings()
                    }

                    VStack(alignment: .leading) {
                        LabeledContent("토치 밝기", value: "\(Int(model.camera.torchLevel * 100))%")
                        Slider(value: $model.camera.torchLevel, in: 0.1...1.0, step: 0.1)
                            .onChange(of: model.camera.torchLevel) { _, _ in
                                if model.camera.isTorchOn { model.camera.setTorch(enabled: true) }
                            }
                    }
                }

                Section("트리거 전후 프레임") {
                    Stepper(
                        "트리거당 후보 \(model.camera.bufferedCandidateCount)장",
                        value: Binding(
                            get: { model.camera.bufferedCandidateCount },
                            set: { model.camera.bufferedCandidateCount = $0 }
                        ),
                        in: 1...5
                    )
                    VStack(alignment: .leading) {
                        LabeledContent(
                            "트리거 이전",
                            value: String(format: "%.2f초", model.camera.preTriggerDuration)
                        )
                        Slider(value: Binding(
                            get: { model.camera.preTriggerDuration },
                            set: { model.camera.preTriggerDuration = $0 }
                        ), in: 0.05...0.45, step: 0.05)
                    }
                    VStack(alignment: .leading) {
                        LabeledContent(
                            "트리거 이후",
                            value: String(format: "%.2f초", model.camera.postTriggerDuration)
                        )
                        Slider(value: Binding(
                            get: { model.camera.postTriggerDuration },
                            set: { model.camera.postTriggerDuration = $0 }
                        ), in: 0.05...0.45, step: 0.05)
                    }
                }

                Section("기기 지원 확인") {
                    LabeledContent("사진 손떨림 보정", value: "시스템 자동")
                    capability("Zero Shutter Lag", model.camera.supportsZeroShutterLag)
                    capability("왜곡 보정", model.camera.supportsDistortionCorrection)
                    capability("Depth / LiDAR", model.camera.supportsDepth)
                    capability("RAW", model.camera.supportsRAW)
                    capability("Apple ProRAW", model.camera.supportsProRAW)
                }

                Section("해석") {
                    Label("낮은 가속 임계값은 작은 움직임에도 민감합니다.", systemImage: "waveform.path")
                    Label("낮은 회전 허용치는 비틀린 움직임을 더 엄격히 제외합니다.", systemImage: "gyroscope")
                    Label("현재 트리거는 이동 방향 전환점을 기준으로 합니다.", systemImage: "arrow.up.and.down")
                }

                Section("현재 카메라 프레임") {
                    LabeledContent("밝기", value: "\(Int(model.camera.frameMetrics.brightness * 100))%")
                    LabeledContent("윤곽 에너지", value: String(format: "%.1f", model.camera.frameMetrics.edgeEnergy))
                    LabeledContent("토치", value: model.camera.isTorchOn ? "켜짐" : "꺼짐")
                    LabeledContent("카메라 세션", value: model.camera.isRunning ? "실행 중" : "정지")
                }
            }
            .navigationTitle("실험 튜닝")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
    }

    private func capability(_ name: String, _ supported: Bool) -> some View {
        LabeledContent(name, value: supported ? "지원" : "미지원")
            .foregroundStyle(supported ? Color.primary : Color.secondary)
    }
}
