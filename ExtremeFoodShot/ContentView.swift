import SwiftUI

struct ContentView: View {
    @StateObject private var model = ExperimentViewModel()
    @State private var showSettings = false
    @State private var showAlbum = false

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
                captureGuide
                controls
            }
            .padding()
        }
        .foregroundStyle(.white)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .sheet(isPresented: $model.showResults) {
            ResultsView(camera: model.camera)
        }
        .sheet(isPresented: $showSettings) {
            TuningView(model: model, motion: model.motion)
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
                VStack(alignment: .leading, spacing: 3) {
                    Text("Best Shot").font(.title2.bold())
                    Text(model.statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Button {
                    showAlbum = true
                } label: {
                    Image(systemName: "photo.stack.fill")
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.14), in: Circle())
                }
                .disabled(model.isExperimentRunning)
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.14), in: Circle())
                }
                .disabled(model.isExperimentRunning)
            }

            HStack {
                Label("초광각 · 자동 촬영", systemImage: "camera.aperture")
                Spacer()
                Label("\(model.camera.candidates.count)/\(model.maximumCandidates)", systemImage: "photo.stack.fill")
                    .monospacedDigit()
            }
            .font(.caption.weight(.semibold))

            if model.camera.authorizationDenied {
                Label("설정에서 카메라 권한을 허용해 주세요.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
            }
            if !model.motion.isAvailable {
                Label("이 기기에서 Device Motion을 사용할 수 없습니다.", systemImage: "waveform.path.ecg")
                    .foregroundStyle(.yellow)
            }
        }
        .padding(14)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
    }

    private var captureGuide: some View {
        VStack(spacing: 12) {
            Image(systemName: model.isExperimentRunning ? "arrow.up.and.down" : "viewfinder")
                .font(.system(size: 34, weight: .light))
            Text(model.isExperimentRunning ? "음식 위에서 부드럽게 움직이세요" : "음식을 가이드 안에 담아주세요")
                .font(.headline)
            if model.isExperimentRunning {
                Text("움직임이 바뀌는 순간 자동으로 촬영합니다")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(.black.opacity(0.38), in: RoundedRectangle(cornerRadius: 20))
    }

    private var controls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                Button {
                    if model.isExperimentRunning { model.finishExperiment() }
                    else { model.beginExperiment() }
                } label: {
                    Label(
                        model.isExperimentRunning ? "촬영 완료" : "자동 촬영 시작",
                        systemImage: model.isExperimentRunning ? "stop.fill" : "camera.fill"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(model.isExperimentRunning ? Color.red : Color.orange, in: Capsule())
                }

                Button {
                    model.showResults = true
                } label: {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title2)
                        .frame(width: 54, height: 54)
                        .background(.white.opacity(0.2), in: Circle())
                }
                .disabled(model.camera.candidates.isEmpty || model.isExperimentRunning)
            }

            Text(model.isExperimentRunning
                 ? "\(model.maximumCandidates - model.camera.candidates.count)장의 후보를 더 촬영할 수 있어요"
                 : "최대 \(model.maximumCandidates)장의 후보 중 베스트 샷을 골라드려요")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(14)
        .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 18))
    }

}
