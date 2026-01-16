import SwiftUI

// MARK: - Share Sheet

/// UIViewControllerRepresentable wrapper for UIActivityViewController.
/// Provides a SwiftUI interface for the native iOS share sheet.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}