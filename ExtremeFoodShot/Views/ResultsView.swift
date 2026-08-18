import Photos
import SwiftUI

struct ResultsView: View {
    @ObservedObject var camera: CameraService
    @State private var saveMessage: String?
    @State private var previewCandidate: CaptureCandidate?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        ScrollView {
            if camera.candidates.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "camera")
                        .font(.largeTitle)
                        .foregroundStyle(Color.fsLime)
                    Text("후보 없음")
                        .font(.fsTitle2)
                        .foregroundStyle(Color.fsWhite)
                    Text("촬영을 다시 진행해 주세요.")
                        .font(.fsBody)
                        .foregroundStyle(Color.fsWhite)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(camera.candidates) { candidate in
                        CandidateCard(
                            candidate: candidate,
                            onSelect: { camera.toggleSelection(for: candidate.id) },
                            onPreview: { previewCandidate = candidate }
                        )
                    }
                }
                .padding()
            }
        }
        .background(Color.fsNavy.ignoresSafeArea())
        .tint(Color.fsLime)
        .navigationTitle("촬영 후보 \(camera.candidates.count)장")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.fsNavy, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("선택 사진 저장(\(selectedCount))") {
                    Task {
                        do {
                            let savedCount = try await camera.saveSelected()
                            saveMessage = "사진 \(savedCount)장을 사진 앱에 저장했습니다."
                        } catch {
                            saveMessage = error.localizedDescription
                        }
                    }
                }
                .disabled(!camera.candidates.contains(where: \.isSelected))
                .foregroundStyle(Color.fsLime)
            }
        }
        .alert("저장 결과", isPresented: Binding(
            get: { saveMessage != nil },
            set: { if !$0 { saveMessage = nil } }
        )) {
            Button("확인", role: .cancel) { saveMessage = nil }
        } message: {
            Text(saveMessage ?? "")
        }
        .fullScreenCover(item: $previewCandidate) { candidate in
            if let image = candidate.image {
                FullScreenPhotoView(image: image)
            }
        }
    }

    private var selectedCount: Int {
        camera.candidates.filter(\.isSelected).count
    }
}

#if DEBUG
#Preview("촬영 결과") {
    ResultsView(camera: .preview)
}
#Preview("촬영 후보 카드") {
    CandidateCard(candidate: .preview(isSelected: true))
        .frame(width: 190)
        .padding()
}
#endif

private struct CandidateCard: View {
    let candidate: CaptureCandidate
    var onSelect: () -> Void = {}
    var onPreview: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = candidate.image {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .aspectRatio(9.0 / 16.0, contentMode: .fill)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture(perform: onPreview)

                    Button(action: onPreview) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.fsLime)
                            .frame(width: 36, height: 36)
                            .background(.black.opacity(0.55), in: Circle())
                    }
                    .padding(8)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("추천 \(Int(candidate.recommendationScore))")
                        .font(.headline)
                    Spacer()
                    if candidate.isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.fsLime)
                    }
                }
                Text(candidate.isSelected ? "선택한 사진" : "탭해서 선택")
                    .foregroundStyle(Color.fsWhite)
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .foregroundStyle(Color.fsLime)
                    Text("설정 \(candidate.testSettings.exposure.shortLabel)")
                    if let exposure = candidate.exposureDuration {
                        Text("· 실제 \(formattedShutterSpeed(exposure))")
                    }
                }
                .foregroundStyle(Color.fsWhite)
                .monospacedDigit()
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
        }
        .font(.caption)
        .foregroundStyle(Color.fsWhite)
        .padding(10)
        .background(candidate.isSelected ? Color.fsLime.opacity(0.18) : Color.fsWhite.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(candidate.isSelected ? Color.fsLime : Color.clear, lineWidth: 2)
        }
    }

    private func formattedShutterSpeed(_ seconds: Double) -> String {
        guard seconds > 0 else { return "-" }
        if seconds >= 1 { return String(format: "%.1f초", seconds) }
        return "1/\(Int((1 / seconds).rounded()))초"
    }
}
