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
                        LabeledContent("최대 후보 수") {
                            Text("\(model.maximumCandidates)장")
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                    }
                } header: {
                    Text("촬영 설정")
                } footer: {
                    Text("자동 촬영이 이 장수에 도달하면 촬영을 마치고 결과를 보여줍니다.")
                }

                Section("촬영 방식") {
                    settingRow("자동 촬영", value: "고화질 사진", icon: "camera.fill")
                    settingRow("렌즈", value: "0.5× 초광각", icon: "camera.aperture")
                    settingRow("조명", value: "토치 100%", icon: "flashlight.on.fill")
                    settingRow("초점 · 색상", value: "자동", icon: "wand.and.stars")
                }

                Section {
                    Picker("셔터 스피드", selection: exposureBinding) {
                        ForEach(ExposurePreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    HStack {
                        Text("현재 설정")
                        Spacer()
                        Text(camera.exposurePreset.shortLabel + (camera.exposurePreset == .automatic ? "" : "초"))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                } header: {
                    Text("셔터 스피드 테스트")
                } footer: {
                    Text("빠른 셔터는 움직임을 선명하게 멈추고, 느린 셔터는 움직임의 궤적과 블러를 더 많이 남깁니다. 같은 조명과 움직임에서 한 단계씩 바꿔 비교해보세요.")
                }

                Section {
                    Label(
                        "휴대폰을 음식 위에서 위아래로 움직이면 방향이 바뀌는 순간 자동으로 촬영합니다.",
                        systemImage: "arrow.up.and.down"
                    )
                    Label(
                        "카메라가 크게 회전하거나 흔들리면 촬영 순간에서 제외합니다.",
                        systemImage: "gyroscope"
                    )
                } header: {
                    Text("촬영 팁")
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
    }

    private var exposureBinding: Binding<ExposurePreset> {
        Binding(
            get: { camera.exposurePreset },
            set: { camera.setExposurePreset($0) }
        )
    }

    private func settingRow(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
                .frame(width: 24)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

#if DEBUG
#Preview("촬영 설정") {
    let model = ExperimentViewModel()
    TuningView(model: model, motion: model.motion, camera: model.camera)
}
#endif
