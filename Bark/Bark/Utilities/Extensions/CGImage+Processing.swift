import CoreGraphics
import CoreImage
import UIKit

extension CGImage {
    /// Creates a grayscale version of the image
    var grayscale: CGImage? {
        let ciImage = CIImage(cgImage: self)
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(0.0, forKey: kCIInputSaturationKey)

        guard let outputImage = filter?.outputImage else { return nil }

        let context = CIContext()
        return context.createCGImage(outputImage, from: outputImage.extent)
    }

    /// Crops the image to the specified rectangle
    func cropped(to rect: CGRect) -> CGImage? {
        return self.cropping(to: rect)
    }

    /// Resizes the image to the specified size
    func resized(to size: CGSize) -> CGImage? {
        let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue
        )

        context?.interpolationQuality = .high
        context?.draw(self, in: CGRect(origin: .zero, size: size))

        return context?.makeImage()
    }

    /// Returns the average brightness of the image (0.0-1.0)
    var averageBrightness: Double {
        guard let data = dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return 0.5
        }

        let totalPixels = width * height
        var totalBrightness: Double = 0

        for i in 0..<totalPixels {
            let offset = i * 4
            let r = Double(bytes[offset])
            let g = Double(bytes[offset + 1])
            let b = Double(bytes[offset + 2])
            // Luminance formula
            totalBrightness += (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
        }

        return totalBrightness / Double(totalPixels)
    }

    /// Extracts a horizontal line of pixel values
    func horizontalSlice(at y: Int) -> [UInt8]? {
        guard y >= 0 && y < height,
              let data = dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return nil
        }

        var slice: [UInt8] = []
        let bytesPerPixel = bitsPerPixel / 8
        let bytesPerRow = self.bytesPerRow

        for x in 0..<width {
            let offset = y * bytesPerRow + x * bytesPerPixel
            // Use green channel as luminance approximation
            slice.append(bytes[offset + 1])
        }

        return slice
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    /// Creates a UIImage from a CVPixelBuffer
    convenience init?(pixelBuffer: CVPixelBuffer) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        self.init(cgImage: cgImage)
    }

    /// Resizes the image to fit within the specified maximum dimension
    func resized(maxDimension: CGFloat) -> UIImage? {
        let scale: CGFloat
        if size.width > size.height {
            scale = maxDimension / size.width
        } else {
            scale = maxDimension / size.height
        }

        guard scale < 1 else { return self }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resized
    }
}
