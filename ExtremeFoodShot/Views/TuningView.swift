import SwiftUI

struct TuningView: View {
    @ObservedObject var model: ExperimentViewModel
    @ObservedObject var motion: MotionAnalyzer
    @Environment(\.dismiss) private var dismiss

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
}

