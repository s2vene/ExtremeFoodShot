import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        InformationDocumentView(
            title: "개인정보처리방침",
            sections: [
                InformationSection(
                    title: "처리하는 정보와 목적",
                    body: "포착은 사진 촬영을 위해 카메라 영상과 촬영 결과를 처리하며, 자동 촬영 시점을 판단하기 위해 기기의 움직임 정보를 처리합니다. 이 정보는 촬영과 앨범 기능을 제공하는 목적으로만 사용됩니다."
                ),
                InformationSection(
                    title: "처리 및 보관 방식",
                    body: "카메라 영상과 움직임 정보는 기기 안에서 처리되며 개발자가 운영하는 서버로 전송되거나 개발자에게 수집되지 않습니다. 촬영한 사진과 앨범은 사용자의 기기 내 앱 저장 공간에 보관됩니다."
                ),
                InformationSection(
                    title: "사진 앱 접근",
                    body: "사용자가 저장을 선택한 사진만 iPhone의 사진 앱에 추가됩니다. 사진 앱에 저장된 사진의 관리와 삭제는 사용자가 사진 앱에서 직접 수행할 수 있습니다."
                ),
                InformationSection(
                    title: "외부 서비스 공유",
                    body: "사용자가 Instagram 스토리 공유 버튼을 직접 선택한 경우에만 선택한 사진 1장이 Instagram 앱으로 전달됩니다. 전달 이후의 정보 처리는 Instagram의 개인정보처리방침과 이용약관을 따릅니다."
                ),
                InformationSection(
                    title: "보유기간 및 삭제",
                    body: "앱 내부의 사진과 앨범은 사용자가 삭제하거나 앱을 제거할 때까지 기기에 보관됩니다. 앨범 삭제 기능을 사용하면 해당 앨범과 앱 내부 사진 파일이 삭제됩니다. 사진 앱이나 Instagram에 전달한 사본은 각 서비스에서 별도로 관리해야 합니다."
                ),
                InformationSection(
                    title: "권한 변경 및 동의 철회",
                    body: "사용자는 iPhone 설정에서 언제든지 카메라, 동작 및 피트니스, 사진 접근 권한을 변경하거나 철회할 수 있습니다. 필수 권한을 철회하면 관련 촬영 또는 저장 기능이 동작하지 않을 수 있습니다."
                ),
                InformationSection(
                    title: "문의처",
                    body: "개인정보 처리와 관련한 문의는 s2vene.dev@gmail.com으로 보내주세요."
                ),
                InformationSection(
                    title: "이메일 문의 정보",
                    body: "사용자가 이메일로 문의하면 이메일 주소, 문의 내용과 사용자가 직접 첨부한 파일을 전달받을 수 있습니다. 해당 정보는 문의 확인과 답변 목적으로만 이용하며, 문의 처리가 끝나면 관련 법령에 따라 보관할 필요가 있는 경우를 제외하고 지체 없이 삭제합니다."
                ),
                InformationSection(
                    title: "방침 변경",
                    body: "앱의 기능이나 정보 처리 방식이 변경되면 이 개인정보처리방침을 업데이트하고 변경된 시행일을 표시합니다."
                ),
                InformationSection(
                    title: "시행일",
                    body: "2026년 8월 25일"
                )
            ]
        )
    }
}

struct ContactView: View {
    var body: some View {
        InformationDocumentView(
            title: "문의하기",
            sections: [
                InformationSection(
                    title: "문의 이메일",
                    body: "s2vene.dev@gmail.com"
                ),
                InformationSection(
                    title: "문의 안내",
                    body: "앱 이용 중 불편한 점이나 개선 의견을 이메일로 보내주세요."
                ),
                InformationSection(
                    title: "함께 알려주세요",
                    body: "사용 중인 iPhone 모델, iOS 버전, 앱 버전, 문제가 발생한 상황과 재현 방법을 함께 보내주시면 더 빠르게 확인할 수 있습니다."
                ),
                InformationSection(
                    title: "사진 첨부",
                    body: "문제 화면을 촬영한 스크린샷을 첨부할 때는 개인 정보나 민감한 내용이 포함되지 않았는지 먼저 확인해 주세요."
                )
            ]
        )
    }
}

private struct InformationSection {
    let title: String
    let body: String
}

private struct InformationDocumentView: View {
    let title: String
    let sections: [InformationSection]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.title)
                            .font(.fsTitle2)
                            .foregroundStyle(Color.fsWhite)

                        Text(section.body)
                            .font(.fsBody)
                            .foregroundStyle(Color.fsWhite.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
            .textSelection(.enabled)
        }
        .background(Color.fsNavy.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.fsNavy, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

#if DEBUG
#Preview("개인정보처리방침") {
    NavigationStack {
        PrivacyPolicyView()
    }
}

#Preview("문의하기") {
    NavigationStack {
        ContactView()
    }
}
#endif
