import SwiftUI

struct AlbumView: View {
    @ObservedObject var album: AlbumStore

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 14)]

    var body: some View {
        Group {
            if album.sessions.isEmpty {
                ContentUnavailableView(
                    "아직 촬영 기록이 없어요",
                    systemImage: "photo.stack",
                    description: Text("자동 촬영을 완료하면 후보 사진이 여기에 보관됩니다.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(album.sessions) { session in
                            NavigationLink(value: session.id) {
                                sessionCard(session)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationDestination(for: UUID.self) { id in
            if let session = album.sessions.first(where: { $0.id == id }) {
                AlbumSessionView(session: session, album: album)
            }
        }
        .navigationTitle("촬영 앨범")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sessionCard(_ session: AlbumSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let image = session.coverImage {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Color.secondary.opacity(0.15)
                }
            }
            .frame(height: 210)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text(session.capturedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline.weight(.semibold))
            Label("후보 \(session.photos.count)장", systemImage: "photo.stack.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#if DEBUG
#Preview("촬영 앨범") {
    AlbumView(album: .preview)
}
#endif

private struct AlbumSessionView: View {
    let session: AlbumSession
    @ObservedObject var album: AlbumStore
    @State private var selectedPhoto: AlbumPhoto?
    @State private var saveMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(session.photos) { photo in
                    if let image = photo.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .aspectRatio(9.0 / 16.0, contentMode: .fill)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(selectedPhoto?.id == photo.id ? .orange : .clear, lineWidth: 3)
                            }
                            .onTapGesture { selectedPhoto = photo }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(session.capturedAt.formatted(date: .abbreviated, time: .omitted))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("사진 앱에 저장") {
                    guard let selectedPhoto else { return }
                    Task {
                        do {
                            try await album.saveToPhotoLibrary(selectedPhoto)
                            saveMessage = "사진 앱에 저장했습니다."
                        } catch {
                            saveMessage = error.localizedDescription
                        }
                    }
                }
                .disabled(selectedPhoto == nil)
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

#if DEBUG
#Preview("앨범 상세") {
    NavigationStack {
        AlbumSessionView(
            session: AlbumSession(id: UUID(), capturedAt: Date(), photos: []),
            album: AlbumStore()
        )
    }
}
#endif
