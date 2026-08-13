import Foundation
import UIKit

struct AlbumSession: Codable, Identifiable {
    let id: UUID
    let capturedAt: Date
    let photos: [AlbumPhoto]

    var coverImage: UIImage? { photos.first?.image }
}

struct AlbumPhoto: Codable, Identifiable {
    let id: UUID
    let fileURL: URL
    let score: Double

    var image: UIImage? { UIImage(contentsOfFile: fileURL.path) }
}
