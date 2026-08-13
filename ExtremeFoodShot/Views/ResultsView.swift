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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = candidate.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .aspectRatio(9.0 / 16.0, contentMode: .fill)
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
            Text(candidate.isSelected ? "선택한 사진" : "탭해서 선택")
                .foregroundStyle(.secondary)
            HStack(spacing: 5) {
                Image(systemName: "timer")
                Text("설정 \(candidate.testSettings.exposure.shortLabel)")
                if let exposure = candidate.exposureDuration {
                    Text("· 실제 \(formattedShutterSpeed(exposure))")
                }
            }
            .foregroundStyle(.secondary)
            .monospacedDigit()
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

    private func formattedShutterSpeed(_ seconds: Double) -> String {
        guard seconds > 0 else { return "-" }
        if seconds >= 1 { return String(format: "%.1f초", seconds) }
        return "1/\(Int((1 / seconds).rounded()))초"
    }
}
