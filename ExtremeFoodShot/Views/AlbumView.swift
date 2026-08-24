import SwiftUI

struct AlbumView: View {
    @ObservedObject var album: AlbumStore
    @State private var isSelecting = false
    @State private var selectedSessionIDs: Set<UUID> = []
    @State private var showsDeleteConfirmation = false
    @State private var deleteMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 14)]
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"
        return formatter
    }()
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        ZStack {
            Color.fsNavy
                .ignoresSafeArea()

            albumContent
        }
        .navigationTitle("촬영 앨범")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isSelecting)
        .foregroundStyle(Color.fsWhite)
        .tint(Color.fsLime)
        .toolbarBackground(Color.fsNavy, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar { albumToolbar }
        .confirmationDialog(
            "선택한 앨범을 삭제할까요?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("앨범 \(selectedSessionIDs.count)개 삭제", role: .destructive) {
                deleteSelectedSessions()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("앨범에 포함된 사진도 앱에서 영구적으로 삭제됩니다.")
        }
        .alert("앨범 삭제", isPresented: Binding(
            get: { deleteMessage != nil },
            set: { if !$0 { deleteMessage = nil } }
        )) {
            Button("확인", role: .cancel) { deleteMessage = nil }
        } message: {
            Text(deleteMessage ?? "")
        }
    }

    @ViewBuilder
    private var albumContent: some View {
        if album.sessions.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.fsWhite.opacity(0.5))
                Text("아직 촬영 기록이 없어요.")
                    .font(.fsBody)
            }
        } else {
            sessionsContent
        }
    }

    private var sessionsContent: some View {
        VStack(alignment: .trailing, spacing: 0) {
            if isSelecting {
                Text("\(selectedSessionIDs.count)/\(album.sessions.count)개 선택됨")
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .font(.fsCaption1)
                    .foregroundStyle(Color.fsWhite.opacity(0.7))
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(groupedSessions, id: \.date) { group in
                        sessionGroup(date: group.date, sessions: group.sessions)
                    }
                }
                .padding()
            }
        }
    }

    private func sessionGroup(date: Date, sessions: [AlbumSession]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(Self.dateFormatter.string(from: date))
                .font(.fsTitle1)

            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(sessions) { session in
                    sessionItem(session)
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var albumToolbar: some ToolbarContent {
        if isSelecting {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    toggleSelectionMode()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 24, height: 24)
                }
                .buttonBorderShape(.circle)
                .accessibilityLabel("앨범 선택 취소")
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    showsDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 24, height: 24)
                }
                .disabled(selectedSessionIDs.isEmpty)
                .foregroundStyle(Color.red)
                .buttonBorderShape(.circle)
                .accessibilityLabel("선택한 앨범 삭제")
            }
        } else {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    toggleSelectionMode()
                } label: {
                    Image(systemName: "checkmark")
                        .frame(width: 24, height: 24)
                }
                .disabled(album.sessions.isEmpty)
                .buttonBorderShape(.circle)
                .accessibilityLabel("앨범 선택")
            }
        }
    }

    private var groupedSessions: [(date: Date, sessions: [AlbumSession])] {
        Dictionary(grouping: album.sessions) {
            Calendar.current.startOfDay(for: $0.capturedAt)
        }
        .map { date, sessions in
            (date: date, sessions: sessions.sorted { $0.capturedAt > $1.capturedAt })
        }
        .sorted { $0.date > $1.date }
    }

    @ViewBuilder
    private func sessionItem(_ session: AlbumSession) -> some View {
        if isSelecting {
            Button {
                toggleSelection(of: session.id)
            } label: {
                sessionCard(session, isSelected: selectedSessionIDs.contains(session.id))
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                AlbumSessionView(session: session, album: album)
            } label: {
                sessionCard(session, isSelected: false)
            }
            .buttonStyle(.plain)
        }
    }

    private func sessionCard(_ session: AlbumSession, isSelected: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
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
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, Color.fsNavy.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 76)
                    .allowsHitTesting(false)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))

                HStack {
                    Text(Self.timeFormatter.string(from: session.capturedAt))
                        .font(.fsBody)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "photo.stack.fill")
                            .foregroundStyle(Color.fsLime)
                        Text("\(session.photos.count)")
                    }
                    .font(.fsBody)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            if isSelected {
                Color.fsLime
                    .opacity(0.4)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .allowsHitTesting(false)

                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.fsLime)
                    .font(.system(size: 25))
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
        .foregroundStyle(Color.fsWhite)
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? Color.fsLime : Color.clear, lineWidth: 2)
        }
    }

    private func toggleSelectionMode() {
        isSelecting.toggle()
        if !isSelecting {
            selectedSessionIDs.removeAll()
        }
    }

    private func toggleSelection(of sessionID: UUID) {
        if selectedSessionIDs.contains(sessionID) {
            selectedSessionIDs.remove(sessionID)
        } else {
            selectedSessionIDs.insert(sessionID)
        }
    }

    private func deleteSelectedSessions() {
        do {
            _ = try album.deleteSessions(withIDs: selectedSessionIDs)
            selectedSessionIDs.removeAll()
            isSelecting = false
        } catch {
            selectedSessionIDs.formIntersection(Set(album.sessions.map(\.id)))
            if selectedSessionIDs.isEmpty {
                isSelecting = false
            }
            deleteMessage = "앨범을 삭제하지 못했습니다. \(error.localizedDescription)"
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
    @State private var selectedPhotoIDs: Set<UUID> = []
    @State private var previewPhoto: AlbumPhoto?
    @State private var saveMessage: String?
    @State private var storyShareMessage: String?
    @State private var sharePayload: SharePayload?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 20)]
    private static let titleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d HH:mm"
        return formatter
    }()

    var body: some View {

        VStack(alignment: .trailing){

            Text("\(selectedPhotoIDs.count)/\(session.photos.count)장 선택됨")
                .padding(.horizontal, 20)
                .padding(.top, 10 )
                .font(.fsCaption1)
                .foregroundStyle(Color.fsWhite.opacity(0.7))

            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(session.photos) { photo in
                        photoCard(photo)
                    }
                }
                .padding(20)
            }



        }
        .background(Color.fsNavy.ignoresSafeArea())
        .foregroundStyle(Color.fsWhite)
        .tint(Color.fsWhite)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(Self.titleFormatter.string(from: session.capturedAt))
        .toolbarBackground(Color.fsNavy, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    saveSelectedPhotos()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .frame(width: 24, height: 24)
                }
                .disabled(selectedPhotoIDs.isEmpty)
                .foregroundStyle(Color.fsWhite)
                .buttonBorderShape(.circle)
            }

            ToolbarSpacer(.fixed, placement: .confirmationAction)

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    shareSelectedPhotos()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 24, height: 24)
                }
                .disabled(selectedPhotoIDs.isEmpty)
                .foregroundStyle(Color.fsWhite)
                .buttonBorderShape(.circle)
                .accessibilityLabel("선택 사진 공유")
            }

            ToolbarSpacer(.fixed, placement: .confirmationAction)

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    shareSelectedPhotoToInstagramStory()
                } label: {
                    Image("instagram icon")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24, height: 24)
                }
                .disabled(selectedPhotoIDs.count != 1)
                .foregroundStyle(Color.fsWhite)
                .buttonBorderShape(.circle)
                .opacity(selectedPhotoIDs.count == 1 ? 1 : 0.3)
                .animation(.easeInOut(duration: 0.15), value: selectedPhotoIDs.count)
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
        .alert("Instagram 스토리 공유", isPresented: Binding(
            get: { storyShareMessage != nil },
            set: { if !$0 { storyShareMessage = nil } }
        )) {
            Button("확인", role: .cancel) { storyShareMessage = nil }
        } message: {
            Text(storyShareMessage ?? "")
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(images: payload.images)
        }
        .fullScreenCover(item: $previewPhoto) { photo in
            let items = previewItems
            if !items.isEmpty {
                FullScreenPhotoView(items: items, initialID: photo.id)
            }
        }
    }

    private var previewItems: [FullScreenPhotoItem] {
        session.photos.compactMap { photo in
            guard let image = photo.image else { return nil }
            return FullScreenPhotoItem(id: photo.id, image: image)
        }
    }

    @ViewBuilder
    private func photoCard(_ photo: AlbumPhoto) -> some View {
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
                            .padding(12)
                            .allowsHitTesting(false)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleSelection(of: photo.id)
                }

                Button {
                    previewPhoto = photo
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.fsWhite)
                        .frame(width: 36, height: 36)
                        .background(.black.opacity(0.55), in: Circle())
                }
                .padding(12)
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

    private func toggleSelection(of photoID: UUID) {
        if selectedPhotoIDs.contains(photoID) {
            selectedPhotoIDs.remove(photoID)
        } else {
            selectedPhotoIDs.insert(photoID)
        }
    }

    private func saveSelectedPhotos() {
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

    private func shareSelectedPhotos() {
        let images = session.photos
            .filter { selectedPhotoIDs.contains($0.id) }
            .compactMap(\.image)

        guard !images.isEmpty else { return }
        sharePayload = SharePayload(images: images)
    }

    private func shareSelectedPhotoToInstagramStory() {
        guard let photo = session.photos.first(where: { selectedPhotoIDs.contains($0.id) }) else {
            return
        }

        do {
            let imageData = try Data(contentsOf: photo.fileURL)
            try InstagramStoryShareService.shared.share(imageData: imageData)
        } catch {
            storyShareMessage = error.localizedDescription
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
