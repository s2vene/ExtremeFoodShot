import Foundation
import UIKit

enum LightingMode: String, CaseIterable, Identifiable {
    case torch = "토치 연속광"
    case flash = "사진 플래시"
    case off = "조명 없음"

    var id: Self { self }
}

enum CameraLens: String, CaseIterable, Identifiable {
    case ultraWide = "초광각"
    case wide = "광각"
    case telephoto = "망원"
    var id: Self { self }
}

enum ExposurePreset: String, CaseIterable, Identifiable {
    case automatic = "자동 · 최대 1/50초"
    case veryFast = "1/1000초"
    case fast = "1/500초"
    case freeze = "빠르게 · 1/250초"
    case action = "1/125초"
    case balanced = "균형 · 1/60초"
    case nearBalanced = "1/50초"
    case slightlyFast = "1/40초"
    case slow = "1/30초"
    case slightlySlow = "1/25초"
    case slower = "1/20초"
    case motionBlur = "블러 · 1/15초"
    var id: Self { self }

    var duration: Double? {
        switch self {
        case .automatic: nil
        case .veryFast: 1.0 / 1_000.0
        case .fast: 1.0 / 500.0
        case .freeze: 1.0 / 250.0
        case .action: 1.0 / 125.0
        case .balanced: 1.0 / 60.0
        case .nearBalanced: 1.0 / 50.0
        case .slightlyFast: 1.0 / 40.0
        case .slow: 1.0 / 30.0
        case .slightlySlow: 1.0 / 25.0
        case .slower: 1.0 / 20.0
        case .motionBlur: 1.0 / 15.0
        }
    }

    var shortLabel: String {
        switch self {
        case .automatic: "자동(최대 1/50)"
        case .veryFast: "1/1000"
        case .fast: "1/500"
        case .freeze: "1/250"
        case .action: "1/125"
        case .balanced: "1/60"
        case .nearBalanced: "1/50"
        case .slightlyFast: "1/40"
        case .slow: "1/30"
        case .slightlySlow: "1/25"
        case .slower: "1/20"
        case .motionBlur: "1/15"
        }
    }
}

enum FocusPreset: String, CaseIterable, Identifiable {
    case continuous = "연속 자동"
    case centerOnce = "중앙 한 번"
    case locked = "현재 위치 고정"
    var id: Self { self }
}

enum WhiteBalancePreset: String, CaseIterable, Identifiable {
    case automatic = "자동"
    case locked = "현재 색온도 고정"
    var id: Self { self }
}

enum CaptureQualityPreset: String, CaseIterable, Identifiable {
    case speed = "속도 우선"
    case balanced = "균형"
    case quality = "화질 우선"
    var id: Self { self }
}

enum AutomaticCaptureMode: String, CaseIterable, Identifiable {
    case photo = "고화질 사진"
    case bufferedFrames = "전후 영상 프레임"
    var id: Self { self }
}

enum CaptureAspectRatio: String, CaseIterable, Identifiable {
    case portrait16x9 = "9:16"
    case square = "1:1"
    case portrait3x4 = "3:4"

    var id: Self { self }

    var value: CGFloat {
        switch self {
        case .portrait16x9: 9.0 / 16.0
        case .square: 1.0
        case .portrait3x4: 3.0 / 4.0
        }
    }
}

enum MotionPhase: String {
    case idle = "대기"
    case movingDown = "아래로 이동"
    case movingUp = "위로 이동"
    case turning = "방향 전환"
    case unstable = "회전 흔들림"
}

struct MotionSnapshot {
    let timestamp: TimeInterval
    let axialAcceleration: Double
    let accelerationMagnitude: Double
    let rotationMagnitude: Double
    let stability: Double
    let phase: MotionPhase
    let triggerScore: Double
}

struct FrameMetrics {
    var brightness: Double = 0
    var edgeEnergy: Double = 0
    var timestamp: TimeInterval = 0
}

struct CameraTestSnapshot {
    let aspectRatio: CaptureAspectRatio
    let lens: CameraLens
    let exposure: ExposurePreset
    let focus: FocusPreset
    let whiteBalance: WhiteBalancePreset
    let quality: CaptureQualityPreset
    let zeroShutterLag: Bool
    let distortionCorrection: Bool
}

struct CaptureCandidate: Identifiable {
    let id = UUID()
    let imageData: Data
    let capturedAt: Date
    let motion: MotionSnapshot
    let frame: FrameMetrics
    let lightingMode: LightingMode
    let exposureDuration: Double?
    let iso: Double?
    let testSettings: CameraTestSnapshot
    var isSelected = false

    var image: UIImage? { UIImage(data: imageData) }

    var recommendationScore: Double {
        let motionScore = min(motion.triggerScore / 4, 1) * 55
        let rotationPenalty = min(motion.rotationMagnitude / 4, 1) * 25
        let detailScore = min(frame.edgeEnergy / 18, 1) * 25
        let exposureScore = (0.12...0.92).contains(frame.brightness) ? 20.0 : 5.0
        return max(0, min(100, motionScore + detailScore + exposureScore - rotationPenalty))
    }
}

#if DEBUG
extension CaptureCandidate {
    static func preview(
        color: UIColor = .systemOrange,
        exposure: ExposurePreset = .slow,
        isSelected: Bool = false
    ) -> CaptureCandidate {
        let size = CGSize(width: 540, height: 960)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))

            UIColor.white.withAlphaComponent(0.28).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 90, y: 250, width: 360, height: 360))
            UIColor.white.withAlphaComponent(0.75).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 175, y: 335, width: 190, height: 190))
        }

        return CaptureCandidate(
            imageData: image.jpegData(compressionQuality: 0.9) ?? Data(),
            capturedAt: Date(),
            motion: MotionSnapshot(
                timestamp: 1,
                axialAcceleration: 0.46,
                accelerationMagnitude: 0.58,
                rotationMagnitude: 0.32,
                stability: 0.91,
                phase: .turning,
                triggerScore: 3.4
            ),
            frame: FrameMetrics(brightness: 0.62, edgeEnergy: 15, timestamp: 1),
            lightingMode: .torch,
            exposureDuration: exposure.duration,
            iso: 125,
            testSettings: CameraTestSnapshot(
                aspectRatio: .portrait16x9,
                lens: .ultraWide,
                exposure: exposure,
                focus: .continuous,
                whiteBalance: .automatic,
                quality: .speed,
                zeroShutterLag: false,
                distortionCorrection: false
            ),
            isSelected: isSelected
        )
    }
}
#endif
