import AVFoundation
import CoreImage
import Photos
import SwiftUI
import UIKit

final class CameraService: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published private(set) var authorizationDenied = false
    @Published private(set) var isRunning = false
    @Published private(set) var isTorchOn = false
    @Published private(set) var isCapturing = false
    @Published private(set) var frameMetrics = FrameMetrics()
    @Published private(set) var candidates: [CaptureCandidate] = []
    @Published private(set) var availableLenses: [CameraLens] = [.wide]
    @Published private(set) var supportsZeroShutterLag = false
    @Published private(set) var supportsDistortionCorrection = false
    @Published private(set) var supportsDepth = false
    @Published private(set) var supportsRAW = false
    @Published private(set) var supportsProRAW = false
    @Published var selectedLens: CameraLens = .ultraWide
    @Published private(set) var automaticCaptureMode: AutomaticCaptureMode = .photo
    @Published private(set) var exposurePreset: ExposurePreset = .slow
    @Published private(set) var focusPreset: FocusPreset = .continuous
    @Published private(set) var whiteBalancePreset: WhiteBalancePreset = .automatic
    @Published private(set) var captureQuality: CaptureQualityPreset = .speed
    @Published private(set) var torchLevel = 1.0
    @Published private(set) var zeroShutterLagEnabled = false
    @Published private(set) var distortionCorrectionEnabled = false
    @Published var preTriggerDuration = 0.20
    @Published var postTriggerDuration = 0.30
    @Published var bufferedCandidateCount = 3
    @Published var errorMessage: String?

    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let frameQueue = DispatchQueue(label: "camera.frame.queue")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let imageContext = CIContext(options: [.cacheIntermediates: false])
    private var camera: AVCaptureDevice?
    private var cameraInput: AVCaptureDeviceInput?
    private var isConfigured = false
    private var pending: [Int64: PendingCapture] = [:]
    private let pendingLock = NSLock()
    private var frameBuffer: [BufferedFrame] = []
    private var lastBufferedFrameTime: TimeInterval = 0
    private var wantsSessionRunning = false
    private var hasReceivedFrame = false
    private let frameStateLock = NSLock()
    private var recoveryAttempt = 0
    private var sessionGeneration = 0

    private struct BufferedFrame {
        let imageData: Data
        let metrics: FrameMetrics
    }

    private struct PendingCapture {
        let motion: MotionSnapshot
        let frame: FrameMetrics
        let lighting: LightingMode
        let testSettings: CameraTestSnapshot
    }

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionWasInterrupted),
            name: AVCaptureSession.wasInterruptedNotification,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterruptionEnded),
            name: AVCaptureSession.interruptionEndedNotification,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionRuntimeError),
            name: AVCaptureSession.runtimeErrorNotification,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.configureAndStart() }
                    else { self?.authorizationDenied = true }
                }
            }
        default:
            authorizationDenied = true
        }
    }

    func stop() {
        setTorch(enabled: false)
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.wantsSessionRunning = false
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    func setTorch(enabled: Bool) {
        sessionQueue.async { [weak self] in
            guard let self, let camera = self.camera, camera.hasTorch else {
                DispatchQueue.main.async { self?.isTorchOn = false }
                return
            }
            do {
                try camera.lockForConfiguration()
                if enabled && camera.isTorchModeSupported(.on) {
                    try camera.setTorchModeOn(
                        level: min(Float(self.torchLevel), AVCaptureDevice.maxAvailableTorchLevel)
                    )
                } else {
                    camera.torchMode = .off
                }
                camera.unlockForConfiguration()
                DispatchQueue.main.async { self.isTorchOn = enabled && camera.isTorchActive }
            } catch {
                DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func capture(motion: MotionSnapshot, lighting: LightingMode) {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            let settings: AVCapturePhotoSettings
            if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            } else {
                settings = AVCapturePhotoSettings()
            }
            settings.photoQualityPrioritization = self.photoQualityPrioritization
            if lighting == .flash, self.camera?.hasFlash == true {
                settings.flashMode = .on
            } else {
                settings.flashMode = .off
            }

            self.pendingLock.lock()
            self.pending[settings.uniqueID] = PendingCapture(
                motion: motion,
                frame: self.frameMetrics,
                lighting: lighting,
                testSettings: self.testSettingsSnapshot
            )
            self.pendingLock.unlock()
            DispatchQueue.main.async { self.isCapturing = true }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    /// Keeps the existing motion trigger, but chooses candidates from frames captured
    /// shortly before and after that trigger instead of relying on one delayed shutter.
    func captureBufferedBurst(
        motion: MotionSnapshot,
        lighting: LightingMode,
        maximumCount: Int = 3
    ) {
        guard maximumCount > 0 else { return }
        DispatchQueue.main.async { self.isCapturing = true }

        frameQueue.async { [weak self] in
            guard let self, let triggerFrame = self.frameBuffer.last else {
                DispatchQueue.main.async { self?.isCapturing = false }
                return
            }
            let triggerTime = triggerFrame.metrics.timestamp

            self.frameQueue.asyncAfter(deadline: .now() + self.postTriggerDuration) { [weak self] in
                guard let self else { return }
                let frames = self.frameBuffer.filter {
                    $0.metrics.timestamp >= triggerTime - self.preTriggerDuration
                        && $0.metrics.timestamp <= triggerTime + self.postTriggerDuration
                }
                let selected = self.bestBufferedFrames(
                    from: frames,
                    maximumCount: maximumCount
                )
                let candidates = selected.map { frame in
                    CaptureCandidate(
                        imageData: frame.imageData,
                        capturedAt: Date(),
                        motion: motion,
                        frame: frame.metrics,
                        lightingMode: lighting,
                        exposureDuration: nil,
                        iso: nil,
                        testSettings: self.testSettingsSnapshot
                    )
                }

                DispatchQueue.main.async {
                    self.candidates.append(contentsOf: candidates)
                    self.candidates.sort { $0.recommendationScore > $1.recommendationScore }
                    self.isCapturing = false
                }
            }
        }
    }

    func clearCandidates() {
        candidates.removeAll()
    }

#if DEBUG
    func loadPreviewCandidates(_ candidates: [CaptureCandidate]) {
        self.candidates = candidates
    }

    static var preview: CameraService {
        let camera = CameraService()
        camera.loadPreviewCandidates([
            .preview(color: .systemOrange, exposure: .slow, isSelected: true),
            .preview(color: .systemTeal, exposure: .slightlyFast),
            .preview(color: .systemIndigo, exposure: .slower)
        ])
        return camera
    }
#endif

    func toggleSelection(for id: UUID) {
        guard let index = candidates.firstIndex(where: { $0.id == id }) else { return }
        for candidateIndex in candidates.indices {
            candidates[candidateIndex].isSelected = candidateIndex == index
        }
    }

    func saveSelected() async throws {
        guard let candidate = candidates.first(where: \.isSelected) else { return }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw CameraError.photoLibraryDenied
        }
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: candidate.imageData, options: nil)
        }
    }

    private func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.wantsSessionRunning = true
            do {
                if !self.isConfigured { try self.configureSession() }
                self.startSessionIfNeeded()
            } catch {
                DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
            }
        }
    }

    private func startSessionIfNeeded() {
        guard wantsSessionRunning else { return }
        if !session.isRunning {
            frameStateLock.lock()
            hasReceivedFrame = false
            frameStateLock.unlock()
            sessionGeneration += 1
            let generation = sessionGeneration
            session.startRunning()
            scheduleFrameWatchdog(for: generation)
        }
        let running = session.isRunning
        DispatchQueue.main.async {
            self.isRunning = running
            if running { self.authorizationDenied = false }
        }
    }

    @objc private func sessionWasInterrupted(_ notification: Notification) {
        DispatchQueue.main.async { self.isRunning = false }
    }

    @objc private func sessionInterruptionEnded(_ notification: Notification) {
        restartSessionWhenAppropriate()
    }

    @objc private func sessionRuntimeError(_ notification: Notification) {
        if let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError {
            DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
        }
        recoverSession()
    }

    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        restartSessionWhenAppropriate()
    }

    private func restartSessionWhenAppropriate() {
        sessionQueue.async { [weak self] in
            self?.startSessionIfNeeded()
        }
    }

    private func scheduleFrameWatchdog(for generation: Int) {
        sessionQueue.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self,
                  self.wantsSessionRunning,
                  self.sessionGeneration == generation,
                  !self.hasReceivedVideoFrame else { return }
            self.recoverSessionOnSessionQueue()
        }
    }

    private var hasReceivedVideoFrame: Bool {
        frameStateLock.lock()
        defer { frameStateLock.unlock() }
        return hasReceivedFrame
    }

    private func confirmVideoFrameDelivery() {
        frameStateLock.lock()
        let isFirstFrame = !hasReceivedFrame
        hasReceivedFrame = true
        frameStateLock.unlock()
        guard isFirstFrame else { return }
        sessionQueue.async { [weak self] in self?.recoveryAttempt = 0 }
    }

    private func recoverSession() {
        sessionQueue.async { [weak self] in
            self?.recoverSessionOnSessionQueue()
        }
    }

    private func recoverSessionOnSessionQueue() {
        guard wantsSessionRunning, recoveryAttempt < 3 else { return }
        recoveryAttempt += 1
        sessionGeneration += 1
        if session.isRunning { session.stopRunning() }

        session.beginConfiguration()
        session.inputs.forEach(session.removeInput)
        session.outputs.forEach(session.removeOutput)
        session.commitConfiguration()
        camera = nil
        cameraInput = nil
        isConfigured = false

        let retryDelay = Double(recoveryAttempt) * 0.35
        sessionQueue.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
            guard let self, self.wantsSessionRunning else { return }
            do {
                try self.configureSession()
                self.startSessionIfNeeded()
            } catch {
                DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
                self.recoverSessionOnSessionQueue()
            }
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo

        guard let camera = cameraDevice(for: selectedLens)
                ?? cameraDevice(for: .wide) else {
            throw CameraError.cameraUnavailable
        }
        self.camera = camera
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else { throw CameraError.configurationFailed }
        session.addInput(input)
        cameraInput = input
        selectedLens = camera.deviceType == .builtInUltraWideCamera ? .ultraWide : .wide

        guard session.canAddOutput(photoOutput) else { throw CameraError.configurationFailed }
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality
        if photoOutput.isResponsiveCaptureSupported {
            photoOutput.isResponsiveCaptureEnabled = true
        }
        if photoOutput.isFastCapturePrioritizationSupported {
            photoOutput.isFastCapturePrioritizationEnabled = true
        }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        videoOutput.setSampleBufferDelegate(self, queue: frameQueue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        applyDeviceControls()
        isConfigured = true
        sessionQueue.async { [weak self] in
            self?.refreshCapabilities()
            self?.applyOutputControls()
        }
    }

    func selectLens(_ lens: CameraLens) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.cameraDevice(for: lens) else { return }
            do {
                let newInput = try AVCaptureDeviceInput(device: device)
                self.session.beginConfiguration()
                if let oldInput = self.cameraInput { self.session.removeInput(oldInput) }
                guard self.session.canAddInput(newInput) else {
                    if let oldInput = self.cameraInput { self.session.addInput(oldInput) }
                    self.session.commitConfiguration()
                    throw CameraError.configurationFailed
                }
                self.session.addInput(newInput)
                self.session.commitConfiguration()
                self.camera = device
                self.cameraInput = newInput
                self.applyDeviceControls()
                self.refreshCapabilities()
                DispatchQueue.main.async { self.selectedLens = lens }
            } catch {
                DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func applyCameraTestSettings() {
        sessionQueue.async { [weak self] in
            self?.applyDeviceControls()
            self?.applyOutputControls()
        }
    }

    func setExposurePreset(_ preset: ExposurePreset) {
        exposurePreset = preset
        sessionQueue.async { [weak self] in
            self?.applyDeviceControls()
        }
    }

    private var photoQualityPrioritization: AVCapturePhotoOutput.QualityPrioritization {
        switch captureQuality {
        case .speed: .speed
        case .balanced: .balanced
        case .quality: .quality
        }
    }

    private var testSettingsSnapshot: CameraTestSnapshot {
        CameraTestSnapshot(
            lens: selectedLens,
            exposure: exposurePreset,
            focus: focusPreset,
            whiteBalance: whiteBalancePreset,
            quality: captureQuality,
            zeroShutterLag: zeroShutterLagEnabled && supportsZeroShutterLag,
            distortionCorrection: distortionCorrectionEnabled && supportsDistortionCorrection
        )
    }

    private func cameraDevice(for lens: CameraLens) -> AVCaptureDevice? {
        let type: AVCaptureDevice.DeviceType
        switch lens {
        case .ultraWide: type = .builtInUltraWideCamera
        case .wide: type = .builtInWideAngleCamera
        case .telephoto: type = .builtInTelephotoCamera
        }
        return AVCaptureDevice.default(type, for: .video, position: .back)
    }

    private func refreshCapabilities() {
        let lenses = CameraLens.allCases.filter { cameraDevice(for: $0) != nil }
        let zsl = photoOutput.isZeroShutterLagSupported
        let distortion = photoOutput.isContentAwareDistortionCorrectionSupported
        let depth = photoOutput.isDepthDataDeliverySupported
        let raw = !photoOutput.availableRawPhotoPixelFormatTypes.isEmpty
        let proRAW = photoOutput.isAppleProRAWSupported
        DispatchQueue.main.async {
            self.availableLenses = lenses
            self.supportsZeroShutterLag = zsl
            self.supportsDistortionCorrection = distortion
            self.supportsDepth = depth
            self.supportsRAW = raw
            self.supportsProRAW = proRAW
        }
    }

    private func applyOutputControls() {
        if photoOutput.isZeroShutterLagSupported {
            photoOutput.isZeroShutterLagEnabled = zeroShutterLagEnabled
        }
        if photoOutput.isContentAwareDistortionCorrectionSupported {
            photoOutput.isContentAwareDistortionCorrectionEnabled = distortionCorrectionEnabled
        }
    }

    private func applyDeviceControls() {
        guard let camera else { return }
        do {
            try camera.lockForConfiguration()
            defer { camera.unlockForConfiguration() }

            if let seconds = exposurePreset.duration {
                let requested = CMTime(seconds: seconds, preferredTimescale: 1_000_000_000)
                let notBelowMinimum = CMTimeCompare(requested, camera.activeFormat.minExposureDuration) < 0
                    ? camera.activeFormat.minExposureDuration : requested
                let duration = CMTimeCompare(notBelowMinimum, camera.activeFormat.maxExposureDuration) > 0
                    ? camera.activeFormat.maxExposureDuration : notBelowMinimum
                camera.setExposureModeCustom(
                    duration: duration,
                    iso: AVCaptureDevice.currentISO,
                    completionHandler: nil
                )
            } else {
                if camera.isExposureModeSupported(.continuousAutoExposure) {
                    camera.exposureMode = .continuousAutoExposure
                }
            }

            switch focusPreset {
            case .continuous:
                if camera.isFocusModeSupported(.continuousAutoFocus) {
                    camera.focusMode = .continuousAutoFocus
                }
            case .centerOnce:
                if camera.isFocusPointOfInterestSupported {
                    camera.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                }
                if camera.isFocusModeSupported(.autoFocus) { camera.focusMode = .autoFocus }
            case .locked:
                if camera.isLockingFocusWithCustomLensPositionSupported {
                    camera.setFocusModeLocked(
                        lensPosition: camera.lensPosition,
                        completionHandler: nil
                    )
                }
            }

            switch whiteBalancePreset {
            case .automatic:
                if camera.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    camera.whiteBalanceMode = .continuousAutoWhiteBalance
                }
            case .locked:
                if camera.isLockingWhiteBalanceWithCustomDeviceGainsSupported {
                    camera.setWhiteBalanceModeLocked(
                        with: camera.deviceWhiteBalanceGains,
                        completionHandler: nil
                    )
                }
            }
        } catch {
            DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
        }
    }

    private func bestBufferedFrames(
        from frames: [BufferedFrame],
        maximumCount: Int
    ) -> [BufferedFrame] {
        let ranked = frames
            .filter { $0.metrics.brightness >= 0.08 }
            .sorted { bufferedFrameScore($0) > bufferedFrameScore($1) }
        var selected: [BufferedFrame] = []
        for frame in ranked {
            guard selected.allSatisfy({
                abs($0.metrics.timestamp - frame.metrics.timestamp) >= 0.06
            }) else { continue }
            selected.append(frame)
            if selected.count == maximumCount { break }
        }
        return selected
    }

    private func bufferedFrameScore(_ frame: BufferedFrame) -> Double {
        let exposure = (0.12...0.92).contains(frame.metrics.brightness) ? 20.0 : 5.0
        let detail = min(frame.metrics.edgeEnergy / 18, 1) * 25
        return exposure + detail
    }

    private func jpegData(from pixelBuffer: CVPixelBuffer) -> Data? {
        let image = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
        return jpegData16By9(from: image)
    }

    private func jpegData16By9(from data: Data) -> Data? {
        guard let image = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
            return nil
        }
        return jpegData16By9(from: image)
    }

    private func jpegData16By9(from image: CIImage) -> Data? {
        let extent = image.extent.integral
        guard extent.width > 0, extent.height > 0 else { return nil }
        let targetRatio = 9.0 / 16.0
        let cropWidth: CGFloat
        let cropHeight: CGFloat
        if extent.width / extent.height > targetRatio {
            cropHeight = extent.height
            cropWidth = cropHeight * targetRatio
        } else {
            cropWidth = extent.width
            cropHeight = cropWidth / targetRatio
        }
        let cropRect = CGRect(
            x: extent.midX - cropWidth / 2,
            y: extent.midY - cropHeight / 2,
            width: cropWidth,
            height: cropHeight
        ).integral
        let cropped = image.cropped(to: cropRect)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return imageContext.jpegRepresentation(
            of: cropped,
            colorSpace: colorSpace,
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.92]
        )
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        pendingLock.lock()
        let capture = pending.removeValue(forKey: photo.resolvedSettings.uniqueID)
        pendingLock.unlock()

        if let error {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isCapturing = false
            }
            return
        }
        guard let capture,
              let originalData = photo.fileDataRepresentation(),
              let data = jpegData16By9(from: originalData) else {
            DispatchQueue.main.async { self.isCapturing = false }
            return
        }

        let exif = photo.metadata[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let exposure = exif?[kCGImagePropertyExifExposureTime as String] as? Double
        let isoValues = exif?[kCGImagePropertyExifISOSpeedRatings as String] as? [Double]
        let candidate = CaptureCandidate(
            imageData: data,
            capturedAt: Date(),
            motion: capture.motion,
            frame: capture.frame,
            lightingMode: capture.lighting,
            exposureDuration: exposure,
            iso: isoValues?.first,
            testSettings: capture.testSettings
        )
        DispatchQueue.main.async {
            self.candidates.append(candidate)
            self.candidates.sort { $0.recommendationScore > $1.recommendationScore }
            self.isCapturing = false
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        confirmVideoFrameDelivery()
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else { return }

        let width = CVPixelBufferGetWidthOfPlane(buffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(buffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        let pixels = base.assumingMemoryBound(to: UInt8.self)
        let step = 16
        var luminance = 0.0
        var edges = 0.0
        var samples = 0
        for y in stride(from: step, to: height - step, by: step) {
            for x in stride(from: step, to: width - step, by: step) {
                let value = Double(pixels[y * bytesPerRow + x])
                let left = Double(pixels[y * bytesPerRow + x - step])
                let above = Double(pixels[(y - step) * bytesPerRow + x])
                luminance += value
                edges += abs(value - left) + abs(value - above)
                samples += 1
            }
        }
        guard samples > 0 else { return }
        let next = FrameMetrics(
            brightness: luminance / Double(samples) / 255,
            edgeEnergy: edges / Double(samples),
            timestamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        )
        if automaticCaptureMode == .bufferedFrames {
            if next.timestamp - lastBufferedFrameTime >= 1.0 / 8.0,
               let imageData = jpegData(from: buffer) {
                frameBuffer.append(BufferedFrame(imageData: imageData, metrics: next))
                lastBufferedFrameTime = next.timestamp
                frameBuffer.removeAll { $0.metrics.timestamp < next.timestamp - 1.10 }
            }
        } else if !frameBuffer.isEmpty {
            // Never retain camera-owned pixel buffers in the normal photo path.
            // Releasing experimental frames also reduces memory pressure while
            // AVCapturePhotoOutput performs a high-resolution capture.
            frameBuffer.removeAll(keepingCapacity: true)
            lastBufferedFrameTime = 0
        }
        DispatchQueue.main.async { self.frameMetrics = next }
    }
}

enum CameraError: LocalizedError {
    case cameraUnavailable
    case configurationFailed
    case photoLibraryDenied

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable: "후면 카메라를 사용할 수 없습니다."
        case .configurationFailed: "카메라 세션을 구성할 수 없습니다."
        case .photoLibraryDenied: "사진 보관함 추가 권한이 필요합니다."
        }
    }
}
