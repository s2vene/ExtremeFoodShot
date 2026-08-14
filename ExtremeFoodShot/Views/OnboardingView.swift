import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // TODO: 온보딩 콘텐츠와 UI를 이 영역에 추가하세요.
                Image(systemName: "hand.wave.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.fsRed)

                Text("온보딩")
                    .font(.fsTitle1)

                Text("앱 사용 방법을 안내하는 내용을 추가해 주세요.")
                    .font(.fsBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .navigationTitle("사용 방법")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
    }
}

#if DEBUG
#Preview("온보딩") {
    OnboardingView()
}
#endif
