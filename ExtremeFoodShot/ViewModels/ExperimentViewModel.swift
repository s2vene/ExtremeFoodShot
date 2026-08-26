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
    @Published private(set) var showNoCandidatesAlert = false
    @Published private(set) var isExperimentRunning = false
    @Published private(set) var isFinishingExperiment = false
    @Published var statusMessage = "음식을 화면 중앙에 맞춰주세요"
    private var didArchiveCurrentSession = false
    private var pendingExpectedCandidateCount = 0
    private var finishRequestedByUser = false
    private var isInBackground = false
    private var shouldStopCameraAfterCapture = false
    private var shouldPresentResultsWhenActive = false
    private var shouldPresentNoCandidatesWhenActive = false

    init() {
        let savedMaximum = UserDefaults.standard.integer(forKey: "maximumCandidates")
        maximumCandidates = savedMaximum == 0 ? 8 : min(max(savedMaximum, 3), 15)
        motion.onTrigger = { [weak self] snapshot in
            guard let self,
                  self.isExperimentRunning,
                  !self.isFinishingExperiment,
                  self.pendingExpectedCandidateCount == 0,
                  !self.camera.isCapturing,
                  self.camera.candidates.count < self.maximumCandidates else { return }
            self.captureAutomatically(snapshot: snapshot)
        }
        camera.onCaptureCompleted = { [weak self] in
            self?.haptics.playCaptureCompleted()
        }
        camera.onCaptureAttemptFinished = { [weak self] addedCount in
            self?.captureAttemptDidFinish(addedCount: addedCount)
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

    func applicationWillResignActive() {
        motion.stop()
        camera.setTorch(enabled: false)
    }

    func applicationDidEnterBackground() {
        guard !isInBackground else { return }
        isInBackground = true
        motion.stop()
        camera.setTorch(enabled: false)

        guard isExperimentRunning else {
            camera.stop()
            return
        }

        finishRequestedByUser = true
        isFinishingExperiment = true
        shouldStopCameraAfterCapture = true
        statusMessage = pendingExpectedCandidateCount > 0 || camera.isCapturing
            ? "마지막 사진을 처리하고 있어요"
            : "촬영이 중단되었어요"
        completeExperimentIfReady()
    }

    func applicationDidBecomeActive() {
        guard isInBackground else {
            start()
            if isExperimentRunning { camera.setTorch(enabled: true) }
            return
        }

        isInBackground = false
        start()
        if shouldPresentResultsWhenActive {
            shouldPresentResultsWhenActive = false
            showResults = true
        } else if shouldPresentNoCandidatesWhenActive {
            shouldPresentNoCandidatesWhenActive = false
            showNoCandidatesAlert = true
        }
    }

    var captureUnavailableMessage: String? {
        if camera.authorizationDenied {
            return "카메라 권한을 허용해야 촬영할 수 있어요."
        }
        if motion.authorizationDenied {
            return "동작 접근을 허용해야 자동 촬영할 수 있어요."
        }
        if !motion.isAvailable {
            return "이 기기에서는 움직임 자동 촬영을 사용할 수 없어요."
        }
        if camera.isRecovering {
            return "카메라 연결을 복구하고 있어요."
        }
        if !camera.isRunning {
            return "카메라를 준비하고 있어요."
        }
        return nil
    }

    var canBeginExperiment: Bool {
        captureUnavailableMessage == nil
    }

    func beginExperiment() {
        guard canBeginExperiment else {
            statusMessage = captureUnavailableMessage ?? "촬영을 시작할 수 없어요."
            return
        }
        camera.clearCandidates()
        didArchiveCurrentSession = false
        pendingExpectedCandidateCount = 0
        finishRequestedByUser = false
        shouldStopCameraAfterCapture = false
        shouldPresentResultsWhenActive = false
        shouldPresentNoCandidatesWhenActive = false
        showNoCandidatesAlert = false
        isFinishingExperiment = false
        isExperimentRunning = true
        statusMessage = "휴대폰을 위아래로 움직여주세요"
        camera.setTorch(enabled: true)
    }

    func finishExperiment() {
        guard isExperimentRunning, !isFinishingExperiment else { return }
        finishRequestedByUser = true
        isFinishingExperiment = true
        statusMessage = pendingExpectedCandidateCount > 0 || camera.isCapturing
            ? "마지막 사진을 처리하고 있어요"
            : "촬영을 마무리하고 있어요"
        camera.setTorch(enabled: false)
        completeExperimentIfReady()
    }

    private func completeExperimentIfReady() {
        guard isExperimentRunning,
              isFinishingExperiment,
              pendingExpectedCandidateCount == 0,
              !camera.isCapturing else { return }

        isExperimentRunning = false
        isFinishingExperiment = false
        finishRequestedByUser = false
        camera.setTorch(enabled: false)
        if !didArchiveCurrentSession, !camera.candidates.isEmpty {
            album.archive(camera.candidates)
            didArchiveCurrentSession = true
        }
        let hasResults = !camera.candidates.isEmpty
        statusMessage = hasResults
            ? "베스트 샷을 확인해보세요"
            : "아직 포착된 사진이 없어요"
        if isInBackground {
            shouldPresentResultsWhenActive = hasResults
            shouldPresentNoCandidatesWhenActive = !hasResults
        } else {
            showResults = hasResults
            showNoCandidatesAlert = !hasResults
        }
        if shouldStopCameraAfterCapture {
            shouldStopCameraAfterCapture = false
            if isInBackground { camera.stop() }
        }
    }

    func manualCapture() {
        statusMessage = "사진을 촬영했어요"
        camera.capture(motion: motion.snapshot, lighting: lightingMode)
    }

    func dismissNoCandidatesAlert() {
        showNoCandidatesAlert = false
    }

    private func captureAutomatically(snapshot: MotionSnapshot) {
        statusMessage = "좋은 순간을 포착했어요"
        let remainingCount = max(0, maximumCandidates - camera.candidates.count)
        let expectedCount: Int
        switch camera.automaticCaptureMode {
        case .photo:
            pendingExpectedCandidateCount = 1
            camera.capture(motion: snapshot, lighting: lightingMode)
            expectedCount = 1
        case .bufferedFrames:
            let burstCount = min(camera.bufferedCandidateCount, remainingCount)
            pendingExpectedCandidateCount = burstCount
            camera.captureBufferedBurst(
                motion: snapshot,
                lighting: lightingMode,
                maximumCount: burstCount
            )
            expectedCount = burstCount
        }
        if camera.candidates.count + expectedCount >= maximumCandidates {
            finishRequestedByUser = false
            isFinishingExperiment = true
            statusMessage = "마지막 사진을 처리하고 있어요"
            camera.setTorch(enabled: false)
        }
    }

    private func captureAttemptDidFinish(addedCount: Int) {
        let expectedCount = pendingExpectedCandidateCount
        pendingExpectedCandidateCount = 0

        if camera.candidates.count >= maximumCandidates {
            isFinishingExperiment = true
        } else if isFinishingExperiment,
                  !finishRequestedByUser,
                  addedCount < expectedCount {
            // A failed photo or a short buffered burst should not end the session
            // before the requested number of candidates has actually been saved.
            isFinishingExperiment = false
            statusMessage = "휴대폰을 위아래로 움직여주세요"
            camera.setTorch(enabled: true)
        }

        completeExperimentIfReady()
    }
}
