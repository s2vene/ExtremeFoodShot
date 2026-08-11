import Photos
import SwiftUI

struct ResultsView: View {
    @ObservedObject var camera: CameraService
    @Environment(\.dismiss) private var dismiss
    @State private var saveMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if camera.candidates.isEmpty {
                    ContentUnavailableView("후보 없음", systemImage: "camera", description: Text("촬영을 다시 진행해 주세요."))
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(camera.candidates) { candidate in
                            CandidateCard(candidate: candidate)
                                .onTapGesture { camera.toggleSelection(for: candidate.id) }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("촬영 후보 \(camera.candidates.count)장")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("선택 사진 저장") {
                        Task {
                            do {
                                try await camera.saveSelected()
                                saveMessage = "사진 앱에 저장했습니다."
                            } catch {
                                saveMessage = error.localizedDescription
                            }
                        }
                    }
                    .disabled(!camera.candidates.contains(where: \.isSelected))
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
        }
    }
}

private struct CandidateCard: View {
    let candidate: CaptureCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = candidate.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 210)
                    .clipped()
            }
            HStack {
                Text("추천 \(Int(candidate.recommendationScore))")
                    .font(.headline)
                Spacer()
                if candidate.isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
            Text("\(candidate.motion.phase.rawValue) · \(candidate.lightingMode.rawValue)")
            Text("\(candidate.testSettings.lens.rawValue) · \(candidate.testSettings.exposure.rawValue)")
            Text("\(candidate.testSettings.focus.rawValue) · \(candidate.testSettings.quality.rawValue)")
            Text(String(format: "축 %.2fg · 회전 %.2f rad/s", candidate.motion.axialAcceleration, candidate.motion.rotationMagnitude))
            if let exposure = candidate.exposureDuration, let iso = candidate.iso {
                Text(String(format: "노출 1/%.0f초 · ISO %.0f", 1 / exposure, iso))
            }
        }
        .font(.caption)
        .padding(10)
        .background(candidate.isSelected ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(candidate.isSelected ? Color.green : Color.clear, lineWidth: 2)
        }
    }
}
