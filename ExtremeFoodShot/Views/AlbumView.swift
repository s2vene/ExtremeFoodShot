import SwiftUI

struct AlbumView: View {
    @ObservedObject var album: AlbumStore

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 14)]

    var body: some View {
        ZStack{
            Color.fsNavy
                .ignoresSafeArea()
            
            Group {
                if album.sessions.isEmpty {
                    ContentUnavailableView(
                        "아직 촬영 기록이 없어요",
                        systemImage: "photo.stack",
                        description: Text("자동 촬영을 완료하면 후보 사진이 여기에 보관됩니다.")
                    )
                    .font(.fsBody)
                
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(album.sessions) { session in
                                NavigationLink {
                                    AlbumSessionView(session: session, album: album)
                                } label: {
                                    sessionCard(session)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("촬영 앨범")
            .navigationBarTitleDisplayMode(.inline)
            .foregroundStyle(Color.fsWhite)
        }
    }

    private func sessionCard(_ session: AlbumSession) -> some View {
        ZStack(alignment: .bottom) {
            Group {
                if let image = session.coverImage {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Color.fsWhite.opacity(0.5)
                }
            }
            .frame(height: 173)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 20))

            HStack{
                Text(session.capturedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.fsBody)
                
                Text("\(session.photos.count)")
                    .font(.fsBody)
            }
            .padding(.bottom, 20)
        }
        .foregroundStyle(Color.fsWhite)
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
    @State private var previewPhoto: AlbumPhoto?
    @State private var saveMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 20)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(session.photos) { photo in
                    if let image = photo.image {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .aspectRatio(9.0 / 16.0, contentMode: .fill)
                                .clipped()
                                .contentShape(Rectangle())
                                .onTapGesture { selectedPhoto = photo }

                            Button {
                                previewPhoto = photo
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 36, height: 36)
                                    .background(.black.opacity(0.55), in: Circle())
                            }
                            .padding(8)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(selectedPhoto?.id == photo.id ? .orange : .clear, lineWidth: 3)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.fsNavy.ignoresSafeArea())
        .foregroundStyle(Color.fsWhite)
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
        .fullScreenCover(item: $previewPhoto) { photo in
            if let image = photo.image {
                FullScreenPhotoView(image: image)
            }
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
