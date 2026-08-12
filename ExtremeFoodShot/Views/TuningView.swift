import SwiftUI

struct TuningView: View {
    @ObservedObject var model: ExperimentViewModel
    @ObservedObject var motion: MotionAnalyzer
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
                    settingRow("초점 · 노출 · 색상", value: "자동", icon: "wand.and.stars")
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
