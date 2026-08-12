import Foundation
import Photos

@MainActor
final class AlbumStore: ObservableObject {
    @Published private(set) var sessions: [AlbumSession] = []
    @Published var errorMessage: String?

    private let fileManager = FileManager.default
    private let rootURL: URL

    init() {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        rootURL = documents.appendingPathComponent("BestShotAlbum", isDirectory: true)
        loadSessions()
    }

    func archive(_ candidates: [CaptureCandidate]) {
        guard !candidates.isEmpty else { return }
        let sessionID = UUID()
        let capturedAt = Date()
        let directory = rootURL.appendingPathComponent(sessionID.uuidString, isDirectory: true)

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let photos = try candidates.enumerated().map { index, candidate in
                let photoID = UUID()
                let fileURL = directory.appendingPathComponent("\(index)-\(photoID.uuidString).jpg")
                try candidate.imageData.write(to: fileURL, options: .atomic)
                return AlbumPhoto(id: photoID, fileURL: fileURL, score: candidate.recommendationScore)
            }
            sessions.insert(
                AlbumSession(id: sessionID, capturedAt: capturedAt, photos: photos),
                at: 0
            )
        } catch {
            errorMessage = "촬영 기록을 저장하지 못했습니다. \(error.localizedDescription)"
        }
    }

    func saveToPhotoLibrary(_ photo: AlbumPhoto) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw CameraError.photoLibraryDenied
        }
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: photo.fileURL, options: nil)
        }
    }

    private func loadSessions() {
        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            let directories = try fileManager.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            sessions = directories.compactMap(loadSession).sorted { $0.capturedAt > $1.capturedAt }
        } catch {
            errorMessage = "이전 촬영 기록을 불러오지 못했습니다. \(error.localizedDescription)"
        }
    }

    private func loadSession(from directory: URL) -> AlbumSession? {
        guard let id = UUID(uuidString: directory.lastPathComponent),
              let files = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
              ) else { return nil }

        let imageFiles = files.filter { $0.pathExtension.lowercased() == "jpg" }.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
        guard !imageFiles.isEmpty else { return nil }
        let date = (try? directory.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
        let photos = imageFiles.map { AlbumPhoto(id: UUID(), fileURL: $0, score: 0) }
        return AlbumSession(id: id, capturedAt: date, photos: photos)
    }
}
