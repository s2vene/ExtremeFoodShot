import Foundation
import UIKit

enum LightingMode: String, CaseIterable, Identifiable {
    case torch = "토치 연속광"
    case flash = "사진 플래시"
    case off = "조명 없음"

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

struct CaptureCandidate: Identifiable {
    let id = UUID()
    let imageData: Data
    let capturedAt: Date
    let motion: MotionSnapshot
    let frame: FrameMetrics
    let lightingMode: LightingMode
    let exposureDuration: Double?
    let iso: Double?
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

