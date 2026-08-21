import SwiftUI
import UIKit

struct SharePayload: Identifiable {
    let id = UUID()
    let images: [UIImage]
}

struct ShareSheet: UIViewControllerRepresentable {
    let images: [UIImage]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: images, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
