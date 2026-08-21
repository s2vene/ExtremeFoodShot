import CoreHaptics
import Foundation

final class HapticService {
    private var engine: CHHapticEngine?
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    init() {
        guard supportsHaptics else { return }

        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            self.engine = engine
        } catch {
            engine = nil
        }
    }

    func playCaptureCompleted() {
        play([
            transientEvent(relativeTime: 0, intensity: 0.55, sharpness: 1.0),
            transientEvent(relativeTime: 0.055, intensity: 0.75, sharpness: 1.0),
            transientEvent(relativeTime: 0.12, intensity: 1.0, sharpness: 0.95)
        ])
    }

    private func play(_ events: [CHHapticEvent]) {
        guard supportsHaptics, let engine else { return }

        do {
            try engine.start()
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // 햅틱 실패가 촬영 흐름을 중단하지 않도록 조용히 건너뜁니다.
        }
    }

    private func transientEvent(
        relativeTime: TimeInterval,
        intensity: Float,
        sharpness: Float
    ) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: relativeTime
        )
    }
}
