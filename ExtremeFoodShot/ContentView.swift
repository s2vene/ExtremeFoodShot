import SwiftUI

struct ContentView: View {
    @StateObject private var model: ExperimentViewModel
    private let startsCaptureServices: Bool
    @State private var showSettings = false
    @State private var showAlbum = false
    
    @MainActor
    init(startsCaptureServices: Bool = true) {
        _model = StateObject(wrappedValue: ExperimentViewModel())
        self.startsCaptureServices = startsCaptureServices
    }
    
    var body: some View {
        ZStack {
            CameraPreview(session: model.camera.session)
                .ignoresSafeArea()
            
            LinearGradient(
                colors: [.black.opacity(0.55), .clear, .black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 14) {
                header
                Spacer()
                controls
            }
            .padding()
        }
        .foregroundStyle(.white)
        .onAppear {
            if startsCaptureServices { model.start() }
        }
        .onDisappear {
            if startsCaptureServices { model.stop() }
        }
        .sheet(isPresented: $model.showResults) {
            ResultsView(camera: model.camera)
        }
        .sheet(isPresented: $showSettings) {
            TuningView(model: model, motion: model.motion, camera: model.camera)
        }
        .sheet(isPresented: $showAlbum) {
            AlbumView(album: model.album)
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
        VStack(spacing: 8) {
            HStack {
                
                Image("logo")
                    .resizable()
                    .frame(width:50, height: 50)
                
                Spacer()
                Button {
                    showAlbum = true
                } label: {
                    Image(systemName: "photo.stack.fill")
                        .foregroundStyle(Color.fsWhite)
                    
                }
                .buttonStyle(.glass)
                .disabled(model.isExperimentRunning)
                
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(Color.fsWhite)
                }
                .buttonStyle(.glass)
                .disabled(model.isExperimentRunning)
            }
            
            
            if model.camera.authorizationDenied {
                Label("설정에서 카메라 권한을 허용해 주세요.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
            }
            if !model.motion.isAvailable {
                Label("이 기기에서 Device Motion을 사용할 수 없습니다.", systemImage: "waveform.path.ecg")
                    .foregroundStyle(.yellow)
            }
        }
    }
    
    
    private var controls: some View {
        VStack(spacing: 14) {
            
            Text(model.isExperimentRunning
                 ? "\(model.camera.candidates.count) / \(model.maximumCandidates)"
                 : "0 / \(model.maximumCandidates)")
            .font(.caption)
            .foregroundStyle(Color.fsWhite)
            
            
            HStack(spacing: 20) {
                
                Button {
                    model.showResults = true
                } label: {
                    HStack(spacing:-2){
                        Image(systemName: "chevron.compact.left")
                        Image(systemName: "photo.on.rectangle.angled")
                }
                        .font(.body)
                        .padding(.vertical, 10)
                        .foregroundStyle(Color.fsWhite)
                        
                }
                .buttonStyle(.glass)
                .disabled(model.camera.candidates.isEmpty || model.isExperimentRunning)
                
                
                Button {
                    if model.isExperimentRunning { model.finishExperiment() }
                    else { model.beginExperiment() }
                } label: {
                    Label("",
                    systemImage: model.isExperimentRunning ? "stop.fill" : "camera.fill"
                          )
                    .labelStyle(.iconOnly)
                    .font(.title2)
                }
                .foregroundStyle(Color.fsNavy)
                .frame(width: 85, height: 85)
                .background(model.isExperimentRunning ? Color.red : Color.fsLime, in: Capsule())
                
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


#if DEBUG
#Preview("메인 촬영 화면") {
    ContentView(startsCaptureServices: false)
}
#endif
