import SwiftUI

struct ContentView: View {
    enum HeaderPreviewState {
        case live
        case cameraAuthorizationDenied
        case motionUnavailable
        case cameraAuthorizationDeniedAndMotionUnavailable
    }

    @StateObject private var model: ExperimentViewModel
    private let startsCaptureServices: Bool
    private let headerPreviewState: HeaderPreviewState
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showSettings = false
    @State private var showOnboarding = false
    @State private var isFirstLaunchOnboarding = false
    @State private var showAlbum = false
    @State private var startsServicesAfterOnboarding = false
    
    @MainActor
    init(
        startsCaptureServices: Bool = true,
        headerPreviewState: HeaderPreviewState = .live
    ) {
        _model = StateObject(wrappedValue: ExperimentViewModel())
        self.startsCaptureServices = startsCaptureServices
        self.headerPreviewState = headerPreviewState
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                CameraPreview(session: model.camera.session)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [Color.fsNavy.opacity(0.7), .clear, Color.fsNavy.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                CaptureAspectRatioMask(camera: model.camera)

                VStack(spacing: 14) {
                    header
                    Spacer()
                    controls
                }
                .padding()
            }
            .foregroundStyle(.white)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $model.showResults) {
                ResultsView(camera: model.camera)
            }
            .navigationDestination(isPresented: $showAlbum) {
                AlbumView(album: model.album)
            }
        }
        .onAppear {
            if presentOnboardingIfNeeded() {
                startsServicesAfterOnboarding = startsCaptureServices
            } else if startsCaptureServices {
                model.start()
            }
        }
        .onDisappear {
            if startsCaptureServices { model.stop() }
        }
        .sheet(isPresented: $showSettings) {
            TuningView(model: model, motion: model.motion, camera: model.camera)
        }
        .sheet(isPresented: $showOnboarding, onDismiss: {
            guard startsServicesAfterOnboarding else { return }
            startsServicesAfterOnboarding = false
            model.start()
        }) {
            OnboardingView(isFirstLaunch: isFirstLaunchOnboarding) {
                hasSeenOnboarding = true
            }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(isFirstLaunchOnboarding)
        }
        .alert("카메라 오류", isPresented: Binding(
            get: { model.camera.errorMessage != nil },
            set: { if !$0 { model.camera.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { model.camera.errorMessage = nil }
        } message: {
            Text(model.camera.errorMessage ?? "")
        }
        .alert("앨범 오류", isPresented: Binding(
            get: { model.album.errorMessage != nil },
            set: { if !$0 { model.album.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { model.album.errorMessage = nil }
        } message: {
            Text(model.album.errorMessage ?? "")
        }
    }
    
    private var header: some View {
        VStack(spacing: 20) {
            HStack {
                
                Image("logo-white")
                    .resizable()
                    .frame(width:40, height: 40)
                
                Spacer()
                Button {
                    showAlbum = true
                } label: {
                    Image(systemName: "photo.stack.fill")
                        .font(.body)
                        .foregroundStyle(Color.fsWhite)
                        .frame(width: 20, height: 30)
                    
                }
                .buttonStyle(.glass)
                .disabled(model.isExperimentRunning)

                Button {
                    isFirstLaunchOnboarding = false
                    showOnboarding = true
                } label: {
                    Image(systemName: "questionmark")
                        .font(.body)
                        .foregroundStyle(Color.fsWhite)
                        .frame(width: 20, height: 30)
                }
                .buttonStyle(.glass)
                .disabled(model.isExperimentRunning)
                
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.body)
                        .foregroundStyle(Color.fsWhite)
                        .frame(width: 20, height: 30)
                }
                .buttonStyle(.glass)
                .disabled(model.isExperimentRunning)
            }
            
            VStack(spacing:10){
                if showsCameraAuthorizationDenied {
                    Label("설정에서 카메라 권한을 허용해 주세요.", systemImage: "exclamationmark.triangle.fill")
                        .font(.fsTitle2)
                        .foregroundStyle(Color.fsLime)
                }
                if showsMotionUnavailable {
                    Label("Device Motion을 사용할 수 없습니다.", systemImage: "waveform.path.ecg")
                        .foregroundStyle(Color.fsLime)
                        .font(.fsTitle2)
                }
            }
        }
    }

    private var showsCameraAuthorizationDenied: Bool {
        switch headerPreviewState {
        case .live:
            model.camera.authorizationDenied
        case .cameraAuthorizationDenied, .cameraAuthorizationDeniedAndMotionUnavailable:
            true
        case .motionUnavailable:
            false
        }
    }

    private var showsMotionUnavailable: Bool {
        switch headerPreviewState {
        case .live:
            !model.motion.isAvailable
        case .motionUnavailable, .cameraAuthorizationDeniedAndMotionUnavailable:
            true
        case .cameraAuthorizationDenied:
            false
        }
    }

    @discardableResult
    private func presentOnboardingIfNeeded() -> Bool {
        guard !hasSeenOnboarding else { return false }
        isFirstLaunchOnboarding = true
        showOnboarding = true
        return true
    }
    
    
    private var controls: some View {
        VStack(spacing: 10) {
            
            Text(model.isExperimentRunning
                 ? "\(model.camera.candidates.count) / \(model.maximumCandidates)"
                 : "0 / \(model.maximumCandidates)")
            .font(.fsBody)
            .foregroundStyle(Color.fsWhite)
            
            
            HStack(spacing: 10) {
                
                Button {
                    model.showResults = true
                } label: {
                    HStack(spacing:-2) {
                        Image(systemName: "chevron.compact.left")
                        Image(systemName: "photo.on.rectangle.angled")


                }
                    .padding(.vertical, 12)
                        .font(.body)
                        .foregroundStyle(Color.fsWhite)
                        
                }
                .buttonStyle(.glass)
                .disabled(model.camera.candidates.isEmpty || model.isExperimentRunning)
                
                ZStack{
                    Image(model.isExperimentRunning ? "logo-red" : "logo")
                        .resizable()
                        .frame(width: 120, height: 120)
                    
                    Button {
                        if model.isExperimentRunning { model.finishExperiment() }
                        else { model.beginExperiment() }
                    } label: {
                        Label("",
                              systemImage: model.isExperimentRunning ? "stop.fill" : "camera.fill"
                        )
                        .labelStyle(.iconOnly)
                        .font(.fsTitle1)
                    }
                    .foregroundStyle(Color.fsNavy)
                }
                
                Button {
                    ()
                } label: {
                    HStack(spacing:-2){
                        Image(systemName: "chevron.compact.left")
                        Image(systemName: "photo.on.rectangle.angled")
                }
                        .font(.body)
                        .padding(.vertical, 10)
                        
                }
                .buttonStyle(.glass)
                .opacity(0)
                
                
            }
            
            
        }
        
        
    }
    
}

private struct CaptureAspectRatioMask: View {
    @ObservedObject var camera: CameraService

    var body: some View {
        GeometryReader { proxy in
            if camera.captureAspectRatio != .portrait16x9 {
                let fullRect = CGRect(origin: .zero, size: proxy.size)
                let clearRect = fittedRect(
                    aspectRatio: camera.captureAspectRatio.value,
                    inside: fullRect
                )

                Path { path in
                    path.addRect(fullRect)
                    path.addRect(clearRect)
                }
                .fill(
                    Color.fsNavy.opacity(0.5),
                    style: FillStyle(eoFill: true)
                )
                .animation(.easeInOut(duration: 0.2), value: camera.captureAspectRatio)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func fittedRect(aspectRatio: CGFloat, inside bounds: CGRect) -> CGRect {
        let boundsRatio = bounds.width / bounds.height
        let size: CGSize

        if boundsRatio > aspectRatio {
            size = CGSize(width: bounds.height * aspectRatio, height: bounds.height)
        } else {
            size = CGSize(width: bounds.width, height: bounds.width / aspectRatio)
        }

        let availableVerticalCrop = max(0, bounds.height - size.height)
        let verticalOffset = availableVerticalCrop * camera.captureAspectRatio.verticalCropBias

        return CGRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2 - verticalOffset,
            width: size.width,
            height: size.height
        )
    }
}


#if DEBUG
#Preview("메인 촬영 화면") {
    ContentView(startsCaptureServices: false)
}

#Preview("헤더 · 카메라 권한 거부") {
    ContentView(
        startsCaptureServices: false,
        headerPreviewState: .cameraAuthorizationDenied
    )
}

#Preview("헤더 · 모션 센서 미지원") {
    ContentView(
        startsCaptureServices: false,
        headerPreviewState: .motionUnavailable
    )
}

#Preview("헤더 · 권한 거부 + 모션 미지원") {
    ContentView(
        startsCaptureServices: false,
        headerPreviewState: .cameraAuthorizationDeniedAndMotionUnavailable
    )
}
#endif
