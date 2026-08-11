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
    @Published var errorMessage: String?

    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let frameQueue = DispatchQueue(label: "camera.frame.queue")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let imageContext = CIContext(options: [.cacheIntermediates: false])
    private var camera: AVCaptureDevice?
    private var isConfigured = false
    private var pending: [Int64: PendingCapture] = [:]
    private let pendingLock = NSLock()
    private var frameBuffer: [BufferedFrame] = []
    private var lastBufferedFrameTime: TimeInterval = 0

    private struct BufferedFrame {
        let pixelBuffer: CVPixelBuffer
        let metrics: FrameMetrics
    }

    private struct PendingCapture {
        let motion: MotionSnapshot
        let frame: FrameMetrics
        let lighting: LightingMode
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
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
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
                    try camera.setTorchModeOn(level: min(0.8, AVCaptureDevice.maxAvailableTorchLevel))
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
            settings.photoQualityPrioritization = .speed
            if lighting == .flash, self.camera?.hasFlash == true {
                settings.flashMode = .on
            } else {
                settings.flashMode = .off
            }

            self.pendingLock.lock()
            self.pending[settings.uniqueID] = PendingCapture(
                motion: motion,
                frame: self.frameMetrics,
                lighting: lighting
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

            self.frameQueue.asyncAfter(deadline: .now() + 0.30) { [weak self] in
                guard let self else { return }
                let frames = self.frameBuffer.filter {
                    $0.metrics.timestamp >= triggerTime - 0.20
                        && $0.metrics.timestamp <= triggerTime + 0.30
                }
                let selected = self.bestBufferedFrames(
                    from: frames,
                    maximumCount: maximumCount
                )
                let candidates = selected.compactMap { frame -> CaptureCandidate? in
                    guard let data = self.jpegData(from: frame.pixelBuffer) else { return nil }
                    return CaptureCandidate(
                        imageData: data,
                        capturedAt: Date(),
                        motion: motion,
                        frame: frame.metrics,
                        lightingMode: lighting,
                        exposureDuration: nil,
                        iso: nil
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
            do {
                if !self.isConfigured { try self.configureSession() }
                guard !self.session.isRunning else { return }
                self.session.startRunning()
                DispatchQueue.main.async { self.isRunning = true }
            } catch {
                DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
            }
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        )
        guard let camera = discoverySession.devices.first(where: { $0.deviceType == .builtInUltraWideCamera })
                ?? discoverySession.devices.first(where: { $0.deviceType == .builtInWideAngleCamera }) else {
            throw CameraError.cameraUnavailable
        }
        self.camera = camera
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else { throw CameraError.configurationFailed }
        session.addInput(input)

        guard session.canAddOutput(photoOutput) else { throw CameraError.configurationFailed }
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .speed
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
        isConfigured = true
    }

    private func bestBufferedFrames(
        from frames: [BufferedFrame],
        maximumCount: Int
    ) -> [BufferedFrame] {
        let ranked = frames.sorted { bufferedFrameScore($0) > bufferedFrameScore($1) }
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
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return imageContext.jpegRepresentation(
            of: image,
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
        guard let capture, let data = photo.fileDataRepresentation() else { return }

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
            iso: isoValues?.first
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
        if next.timestamp - lastBufferedFrameTime >= 1.0 / 15.0 {
            frameBuffer.append(BufferedFrame(pixelBuffer: buffer, metrics: next))
            lastBufferedFrameTime = next.timestamp
            frameBuffer.removeAll { $0.metrics.timestamp < next.timestamp - 0.65 }
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
