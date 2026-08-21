import Foundation

@MainActor
final class ExperimentViewModel: ObservableObject {
    var camera = CameraService()
    let motion = MotionAnalyzer()
    let album = AlbumStore()
    private let haptics = HapticService()

    let lightingMode: LightingMode = .torch
    @Published var maximumCandidates: Int {
        didSet {
            let validValue = min(max(maximumCandidates, 3), 15)
            if maximumCandidates != validValue {
                maximumCandidates = validValue
            } else {
                UserDefaults.standard.set(validValue, forKey: "maximumCandidates")
            }
        }
    }
    @Published var showResults = false
    @Published private(set) var isExperimentRunning = false
    @Published var statusMessage = "음식을 화면 중앙에 맞춰주세요"
    private var didArchiveCurrentSession = false

    init() {
        let savedMaximum = UserDefaults.standard.integer(forKey: "maximumCandidates")
        maximumCandidates = savedMaximum == 0 ? 8 : min(max(savedMaximum, 3), 15)
        motion.onTrigger = { [weak self] snapshot in
            guard let self,
                  self.isExperimentRunning,
                  !self.camera.isCapturing,
                  self.camera.candidates.count < self.maximumCandidates else { return }
            self.captureAutomatically(snapshot: snapshot)
        }
        camera.onCaptureCompleted = { [weak self] in
            self?.haptics.playCaptureCompleted()
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
        didArchiveCurrentSession = false
        isExperimentRunning = true
        statusMessage = "휴대폰을 위아래로 움직여주세요"
        camera.setTorch(enabled: true)
    }

    func finishExperiment() {
        isExperimentRunning = false
        camera.setTorch(enabled: false)
        statusMessage = "베스트 샷을 확인해보세요"
        if !didArchiveCurrentSession, !camera.candidates.isEmpty {
            album.archive(camera.candidates)
            didArchiveCurrentSession = true
        }
        showResults = !camera.candidates.isEmpty
    }

    func manualCapture() {
        statusMessage = "사진을 촬영했어요"
        camera.capture(motion: motion.snapshot, lighting: lightingMode)
    }

    private func captureAutomatically(snapshot: MotionSnapshot) {
        statusMessage = "좋은 순간을 포착했어요"
        let remainingCount = max(0, maximumCandidates - camera.candidates.count)
        let expectedCount: Int
        switch camera.automaticCaptureMode {
        case .photo:
            camera.capture(motion: snapshot, lighting: lightingMode)
            expectedCount = 1
        case .bufferedFrames:
            let burstCount = min(camera.bufferedCandidateCount, remainingCount)
            camera.captureBufferedBurst(
                motion: snapshot,
                lighting: lightingMode,
                maximumCount: burstCount
            )
            expectedCount = burstCount
        }
        if camera.candidates.count + expectedCount >= maximumCandidates {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.finishExperiment()
            }
        }
    }
}
