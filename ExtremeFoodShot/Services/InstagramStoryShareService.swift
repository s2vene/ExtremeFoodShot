import UIKit

@MainActor
final class InstagramStoryShareService {
    static let shared = InstagramStoryShareService()

    private init() {}

    func share(imageData: Data) throws {
        guard UIImage(data: imageData) != nil else {
            throw InstagramStoryShareError.invalidImage
        }
        guard let appID = Bundle.main.object(forInfoDictionaryKey: "FacebookAppID") as? String,
              !appID.isEmpty else {
            throw InstagramStoryShareError.missingAppID
        }
        guard let url = URL(
            string: "instagram-stories://share?source_application=\(appID)"
        ), UIApplication.shared.canOpenURL(url) else {
            throw InstagramStoryShareError.instagramUnavailable
        }

        UIPasteboard.general.setItems(
            [["com.instagram.sharedSticker.backgroundImage": imageData]],
            options: [
                .expirationDate: Date().addingTimeInterval(5 * 60)
            ]
        )
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

private enum InstagramStoryShareError: LocalizedError {
    case invalidImage
    case missingAppID
    case instagramUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            "선택한 사진을 읽을 수 없습니다."
        case .missingAppID:
            "Instagram 공유 설정을 확인해 주세요."
        case .instagramUnavailable:
            "Instagram 앱을 설치한 후 다시 시도해 주세요."
        }
    }
}
