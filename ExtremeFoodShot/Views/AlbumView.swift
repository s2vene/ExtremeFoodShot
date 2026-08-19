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
                    .tint(Color.fsLime)
                
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
        .tint(Color.fsLime)
        .toolbarBackground(Color.fsNavy, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
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
                
                HStack(spacing: 4) {
                    Image(systemName: "photo.stack.fill")
                        .foregroundStyle(Color.fsLime)
                    Text("\(session.photos.count)")
                }
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
    @State private var selectedPhotoIDs: Set<UUID> = []
    @State private var previewPhoto: AlbumPhoto?
    @State private var saveMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 20)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(session.photos) { photo in
                    if let image = photo.image {
                        let isSelected = selectedPhotoIDs.contains(photo.id)
                        ZStack(alignment: .topTrailing) {
                            ZStack(alignment: .bottomTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .aspectRatio(image.size.width / image.size.height, contentMode: .fill)
                                    .clipped()

                                if isSelected {
                                    Color.fsLime
                                        .opacity(0.4)
                                        .allowsHitTesting(false)

                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.fsLime)
                                        .font(.system(size: 25))
                                        .padding(20)
                                        .allowsHitTesting(false)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isSelected {
                                    selectedPhotoIDs.remove(photo.id)
                                } else {
                                    selectedPhotoIDs.insert(photo.id)
                                }
                            }

                            Button {
                                previewPhoto = photo
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.fsLime)
                                    .frame(width: 36, height: 36)
                                    .background(.black.opacity(0.55), in: Circle())
                            }
                            .padding(20)
                        }
                        .foregroundStyle(Color.fsWhite)
                        .background(isSelected ? Color.fsLime.opacity(0.18) : Color.fsWhite.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(isSelected ? Color.fsLime : Color.clear, lineWidth: 2)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.fsNavy.ignoresSafeArea())
        .foregroundStyle(Color.fsWhite)
        .tint(Color.fsLime)
        .navigationTitle(session.capturedAt.formatted(date: .abbreviated, time: .omitted))
        .toolbarBackground(Color.fsNavy, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("선택 사진 저장(\(selectedPhotoIDs.count))") {
                    let selectedPhotos = session.photos.filter { selectedPhotoIDs.contains($0.id) }
                    Task {
                        do {
                            let savedCount = try await album.saveToPhotoLibrary(selectedPhotos)
                            saveMessage = "사진 \(savedCount)장을 사진 앱에 저장했습니다."
                        } catch {
                            saveMessage = error.localizedDescription
                        }
                    }
                }
                .disabled(selectedPhotoIDs.isEmpty)
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
