import CoreMotion
import Foundation

final class MotionAnalyzer: ObservableObject {
    @Published private(set) var snapshot = MotionSnapshot(
        timestamp: 0,
        axialAcceleration: 0,
        accelerationMagnitude: 0,
        rotationMagnitude: 0,
        stability: 1,
        phase: .idle,
        triggerScore: 0
    )
    @Published private(set) var axialHistory = Array(repeating: 0.0, count: 80)
    @Published private(set) var isAvailable = true
    @Published private(set) var authorizationDenied = false

    @Published private(set) var triggerThreshold = 0.40
    @Published private(set) var rotationLimit = 3.4
    var onTrigger: ((MotionSnapshot) -> Void)?

    private let manager = CMMotionManager()
    private var lastAxialAcceleration = 0.0
    private var lastTriggerTime = 0.0
    private var activityStarted = false

    func start() {
        refreshAuthorizationStatus()
        guard !authorizationDenied else { return }
        guard !manager.isDeviceMotionActive else { return }

        guard manager.isDeviceMotionAvailable else {
            isAvailable = false
            return
        }

        isAvailable = true
        manager.deviceMotionUpdateInterval = 1.0 / 100.0
        manager.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical, to: .main) { [weak self] motion, error in
            if error != nil {
                self?.refreshAuthorizationStatus()
            }
            guard let self, let motion else { return }
            self.consume(motion)
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }

    func refreshAuthorizationStatus() {
        let status = CMMotionActivityManager.authorizationStatus()
        authorizationDenied = status == .denied || status == .restricted
        isAvailable = manager.isDeviceMotionAvailable && !authorizationDenied
    }

    private func consume(_ motion: CMDeviceMotion) {
        let acceleration = motion.userAcceleration
        let rotation = motion.rotationRate
        let axial = acceleration.z
        let accelerationMagnitude = sqrt(
            acceleration.x * acceleration.x
            + acceleration.y * acceleration.y
            + acceleration.z * acceleration.z
        )
        let rotationMagnitude = sqrt(
            rotation.x * rotation.x
            + rotation.y * rotation.y
            + rotation.z * rotation.z
        )
        let timestamp = motion.timestamp
        let reversal = axial.sign != lastAxialAcceleration.sign
            && abs(lastAxialAcceleration) > triggerThreshold * 0.55
        let stableRotation = rotationMagnitude < rotationLimit
        let stability = max(0, 1 - rotationMagnitude / max(rotationLimit, 0.01))
        let triggerScore = abs(axial) * 2.2 + accelerationMagnitude * 0.8 + stability

        if abs(axial) > triggerThreshold {
            activityStarted = true
        }

        let phase: MotionPhase
        if rotationMagnitude >= rotationLimit {
            phase = .unstable
        } else if reversal && activityStarted {
            phase = .turning
        } else if axial > 0.18 {
            phase = .movingUp
        } else if axial < -0.18 {
            phase = .movingDown
        } else {
            phase = .idle
        }

        let next = MotionSnapshot(
            timestamp: timestamp,
            axialAcceleration: axial,
            accelerationMagnitude: accelerationMagnitude,
            rotationMagnitude: rotationMagnitude,
            stability: stability,
            phase: phase,
            triggerScore: triggerScore
        )
        snapshot = next
        axialHistory.removeFirst()
        axialHistory.append(axial)

        if reversal,
           activityStarted,
           stableRotation,
           timestamp - lastTriggerTime > 0.42 {
            lastTriggerTime = timestamp
            activityStarted = false
            onTrigger?(next)
        }

        lastAxialAcceleration = axial
    }
}
