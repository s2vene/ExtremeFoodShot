import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    let isFirstLaunch: Bool
    var onStart: () -> Void = {}

    @State private var currentStep = 0

    private let steps = OnboardingStep.allCases

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $currentStep) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        OnboardingStepPage(step: step)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageIndicator
                    .padding(.bottom, 18)

                bottomButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(steps.indices, id: \.self) { index in
                Capsule()
                    .fill(index == currentStep ? Color.fsLime : Color.fsWhite.opacity(0.3))
                    .frame(width: index == currentStep ? 24 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: currentStep)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("총 \(steps.count)단계 중 \(currentStep + 1)단계")
    }

    private var bottomButton: some View {
        Button {
            if currentStep < steps.count - 1 {
                withAnimation {
                    currentStep += 1
                }
            } else {
                if isFirstLaunch {
                    onStart()
                }
                dismiss()
            }
        } label: {
            Text(buttonTitle)
                .font(.fsTitle2)
                .foregroundStyle(Color.fsNavy)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.fsLime, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private var buttonTitle: String {
        guard currentStep == steps.count - 1 else { return "다음" }
        return isFirstLaunch ? "다음" : "포착 시작하기"
    }
}

private enum OnboardingStep: CaseIterable {
    case introduction
    case parallel
    case capture
    case share

    var title: String {
        switch self {
        case .introduction:
            "음식의 순간을 포착하라"
        case .parallel:
            "휴대폰을 안정적으로 잡고 흔드세요."
        case .capture:
            "자동으로 적절한 순간을 포착."
        case .share:
            "찍은 사진을 바로 공유하세요."
        }
    }

    var description: String {
        switch self {
        case .introduction:
            "포착을 활용하여\n역동적인 음식 사진을 찍는 법을 알려 드릴게요."
        case .parallel:
            "휴대폰이 음식과 평행하도록 잡고, 촬영 버튼을 한 번 누른 후 휴대폰을 음식을 향해 흔들어 보세요."
        case .capture:
            "가까이 움직이다가 음식에서 멀어지는 순간\n자동으로 사진을 찍습니다."
        case .share:
            "사진 촬영 이후 바로 원하는 사진을 선택하여 공유하고, 인스타그램에 게시하세요."
        }
    }

    var imageName: String {
        switch self {
        case .introduction:
            "onboarding"
        case .parallel:
            "food"
        case .capture:
            "capture"
        case .share:
            "share"
        }
    }
}

private struct OnboardingStepPage: View {
    let step: OnboardingStep

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 12)

            Image(step.imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 180, maxHeight: 180)
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text(step.title)
                    .font(.fsTitle1)
                    .foregroundStyle(step == .introduction ? Color.fsLime : Color.fsWhite)
                    .multilineTextAlignment(.center)

                Text(step.description)
                    .font(.fsBody)
                    .foregroundStyle(Color.fsWhite.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 28)
    }
}

#if DEBUG
#Preview("최초 실행 · 포착 시작하기") {
    OnboardingView(isFirstLaunch: true)
}

#Preview("도움말 · 완료") {
    OnboardingView(isFirstLaunch: false)
}
#endif
