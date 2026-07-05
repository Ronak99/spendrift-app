//
//  ReceiptImagePreparer.swift
//  Spendrift
//
//  Downscales and JPEG-compresses a receipt image so it stays under the backend's
//  MAX_IMAGE_BYTES limit before upload. Always emits JPEG.
//

import Foundation
import UIKit

enum ReceiptImagePreparer {
    /// Mirror of the backend `MAX_IMAGE_BYTES` default (8 MB). Keep a small safety margin below it.
    static let maxBytes = 8 * 1024 * 1024
    static let targetBytes = 7 * 1024 * 1024
    static let maxDimension: CGFloat = 2000

    struct Prepared {
        let data: Data
        let mimeType: String
        let filename: String
    }

    static func prepare(_ image: UIImage) -> Prepared? {
        let resized = downscale(image, maxDimension: maxDimension)

        var quality: CGFloat = 0.85
        guard var data = resized.jpegData(compressionQuality: quality) else { return nil }

        while data.count > targetBytes && quality > 0.3 {
            quality -= 0.15
            guard let smaller = resized.jpegData(compressionQuality: quality) else { break }
            data = smaller
        }

        // Last resort: if still too large, shrink dimensions further and retry once.
        if data.count > maxBytes {
            let smallerImage = downscale(resized, maxDimension: maxDimension * 0.7)
            if let smallerData = smallerImage.jpegData(compressionQuality: 0.6) {
                data = smallerData
            }
        }

        guard data.count <= maxBytes else { return nil }

        return Prepared(
            data: data,
            mimeType: "image/jpeg",
            filename: "receipt-\(UUID().uuidString).jpg"
        )
    }

    static func prepare(data: Data) -> Prepared? {
        guard let image = UIImage(data: data) else { return nil }
        return prepare(image)
    }

    private static func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let largestSide = max(size.width, size.height)
        guard largestSide > maxDimension, largestSide > 0 else { return image }

        let scale = maxDimension / largestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
