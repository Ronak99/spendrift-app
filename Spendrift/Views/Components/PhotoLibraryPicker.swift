//
//  PhotoLibraryPicker.swift
//  Spendrift
//
//  UIKit PHPickerViewController wrapper. Configured without a PHPhotoLibrary, so it
//  runs out-of-process, needs no photo-library permission, and presents once.
//  Replaces SwiftUI's PhotosPicker, which loops/re-presents when hosted in a Form
//  inside a sheet.
//

import PhotosUI
import SwiftUI
import UIKit

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    let onImage: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImage: (UIImage?) -> Void
        private var didFinish = false

        init(onImage: @escaping (UIImage?) -> Void) {
            self.onImage = onImage
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !didFinish else { return }
            didFinish = true

            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                onImage(nil)
                return
            }
            provider.loadObject(ofClass: UIImage.self) { [onImage] object, _ in
                DispatchQueue.main.async {
                    onImage(object as? UIImage)
                }
            }
        }
    }
}
