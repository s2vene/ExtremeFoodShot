import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    let isFirstLaunch: Bool
    var onStart: () -> Void = {}

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                Image("onboarding")
                    .resizable()
                    .frame(width:200, height: 200)

                HStack(spacing:0){
                    Text("음식의 순간을 ")
                        .font(.fsTitle1)
                        .foregroundStyle(Color.fsWhite)
                    Text("포착")
                        .font(.fsTitle1)
                        .foregroundStyle(Color.fsLime)
                    Text("하라")
                        .font(.fsTitle1)
                        .foregroundStyle(Color.fsWhite)
                }

                Text("휴대폰을 안정적으로 잡고\n음식을 향해 흔들어 보세요.")
                    .font(.fsBody)
                    .foregroundStyle(Color.fsWhite)
                    .multilineTextAlignment(.center)

                Spacer()

                if isFirstLaunch {
                    Button {
                        onStart()
                        dismiss()
                    } label: {
                        Text("포착 시작하기")
                            .font(.fsTitle2)
                            .foregroundStyle(Color.fsNavy)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.fsLime, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(20)
            .background(Color.fsNavy)
            .navigationTitle("포착 사용 방법")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.fsNavy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if !isFirstLaunch {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("완료") { dismiss() }
                            .foregroundStyle(Color.fsLime)
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview("온보딩") {
    OnboardingView(isFirstLaunch: true)
}
#endif
