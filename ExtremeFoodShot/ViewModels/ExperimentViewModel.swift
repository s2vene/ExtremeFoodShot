import Foundation

final class ExperimentViewModel: ObservableObject {
    let camera = CameraService()
    let motion = MotionAnalyzer()

    @Published var lightingMode: LightingMode = .torch
    @Published var automaticCapture = true
    @Published var maximumCandidates = 8
    @Published var showResults = false
    @Published var statusMessage = "기기를 음식 위에서 준비하세요"

    private var isExperimentRunning = false

    init() {
        motion.onTrigger = { [weak self] snapshot in
            guard let self,
                  self.isExperimentRunning,
                  self.automaticCapture,
                  !self.camera.isCapturing,
                  self.camera.candidates.count < self.maximumCandidates else { return }
            self.captureBufferedBurst(snapshot: snapshot)
        }
    }

    func start() {
        camera.start()
        motion.start()
    }

    func stop() {
        motion.stop()
        camera.stop()
    }

    func beginExperiment() {
        camera.clearCandidates()
        isExperimentRunning = true
        statusMessage = "위아래로 움직이세요"
        camera.setTorch(enabled: lightingMode == .torch)
    }

    func finishExperiment() {
        isExperimentRunning = false
        camera.setTorch(enabled: false)
        statusMessage = "촬영 완료"
        showResults = !camera.candidates.isEmpty
    }

    func manualCapture() {
        statusMessage = "찰칵 · 수동 촬영"
        camera.capture(motion: motion.snapshot, lighting: lightingMode)
    }

    private func captureBufferedBurst(snapshot: MotionSnapshot) {
        statusMessage = "찰칵 · \(snapshot.phase.rawValue)"
        let remainingCount = max(0, maximumCandidates - camera.candidates.count)
        camera.captureBufferedBurst(
            motion: snapshot,
            lighting: lightingMode,
            maximumCount: min(3, remainingCount)
        )
        if camera.candidates.count + min(3, remainingCount) >= maximumCandidates {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.finishExperiment()
            }
        }
    }
}
