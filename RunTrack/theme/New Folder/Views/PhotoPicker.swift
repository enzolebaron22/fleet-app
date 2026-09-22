import SwiftUI
import PhotosUI

/// Sélecteur de photo natif iOS, pour choisir une photo depuis la pellicule.
struct PhotoPicker: UIViewControllerRepresentable {
    var onPick: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (UIImage) -> Void

        init(onPick: @escaping (UIImage) -> Void) {
            self.onPick = onPick
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                if let uiImage = image as? UIImage {
                    DispatchQueue.main.async {
                        self.onPick(uiImage)
                    }
                }
            }
        }
    }
}
