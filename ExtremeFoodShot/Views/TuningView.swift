import SwiftUI

struct TuningView: View {
    @ObservedObject var model: ExperimentViewModel
    @ObservedObject var motion: MotionAnalyzer
    @ObservedObject var camera: CameraService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $model.maximumCandidates, in: 3...15) {
                        LabeledContent("최대 촬영 수") {
                            Text("\(model.maximumCandidates)장")
                                .font(.fsTitle2)
                                .monospacedDigit()
                        }
                        .font(.fsBody)
                    }
                }
                .padding(6)
                .listRowBackground(Color.fsWhite.opacity(0.05))

                Section {
                    Picker("촬영 비율", selection: $camera.captureAspectRatio) {
                        ForEach(CaptureAspectRatio.allCases) { ratio in
                            Text(ratio.rawValue).tag(ratio)
                        }
                    }
                    .font(.fsBody)
                }
                .padding(6)
                .listRowBackground(Color.fsWhite.opacity(0.05))


                Section {
                    settingRow("렌즈", value: "0.5× 초광각", icon: "camera.aperture")
                    settingRow("조명", value: "토치 100%", icon: "flashlight.on.fill")
                    settingRow("초점", value: "자동", icon: "wand.and.stars")
                    settingRow("셔터 스피드", value: "1/50초", icon: "timer")
                }
                .font(.fsBody)
                .padding(6)
                .listRowBackground(Color.fsWhite.opacity(0.05))

            }
            .scrollContentBackground(.hidden)
            .listSectionSpacing(8)
            .background(Color.fsNavy)
            .foregroundStyle(Color.fsWhite)
            .tint(Color.fsLime)
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.fsNavy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                        .foregroundStyle(Color.fsLime)
                }
            }

        }
    }

    private func settingRow(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.fsLime)
                .frame(width: 20)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(Color.fsWhite)
        }
    }

}

#if DEBUG
#Preview("촬영 설정") {
    let model = ExperimentViewModel()
    TuningView(model: model, motion: model.motion, camera: model.camera)
}
#endif
