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
    case automatic = "자동"
    case freeze = "빠르게 · 1/250초"
    case balanced = "균형 · 1/60초"
    case motionBlur = "블러 · 1/15초"
    var id: Self { self }
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
