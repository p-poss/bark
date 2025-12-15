import CoreImage
import CoreVideo
import Accelerate

/// Metal-accelerated image processing for bark analysis
final class ImageProcessor {
    private let context: CIContext
    private let grayscaleFilter: CIFilter?

    init() {
        // Use Metal for GPU-accelerated processing
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            context = CIContext(mtlDevice: metalDevice, options: [
                .workingColorSpace: CGColorSpaceCreateDeviceRGB(),
                .cacheIntermediates: false
            ])
        } else {
            context = CIContext(options: [.useSoftwareRenderer: false])
        }

        grayscaleFilter = CIFilter(name: "CIColorControls")
    }

    // MARK: - Grayscale Conversion

    /// Converts a pixel buffer to grayscale
    func toGrayscale(_ pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        grayscaleFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        grayscaleFilter?.setValue(0.0, forKey: kCIInputSaturationKey)

        guard let outputImage = grayscaleFilter?.outputImage else { return nil }

        var outputBuffer: CVPixelBuffer?
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_OneComponent8,
            nil,
            &outputBuffer
        )

        if let buffer = outputBuffer {
            context.render(outputImage, to: buffer)
        }

        return outputBuffer
    }

    // MARK: - Adaptive Thresholding

    /// Applies adaptive thresholding to isolate bark fissures
    func adaptiveThreshold(_ pixelBuffer: CVPixelBuffer, blockSize: Int = 15) -> [UInt8]? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)

        // Convert to grayscale values array
        var grayscale = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                // For BGRA format, use green channel as luminance approximation
                let offset = y * bytesPerRow + x * 4
                grayscale[y * width + x] = buffer[offset + 1] // Green channel
            }
        }

        // Apply adaptive threshold using integral image
        var output = [UInt8](repeating: 0, count: width * height)
        let integral = computeIntegralImage(grayscale, width: width, height: height)

        let halfBlock = blockSize / 2
        let threshold: Double = 0.85 // Threshold factor

        for y in 0..<height {
            for x in 0..<width {
                let x1 = max(0, x - halfBlock)
                let y1 = max(0, y - halfBlock)
                let x2 = min(width - 1, x + halfBlock)
                let y2 = min(height - 1, y + halfBlock)

                let count = (x2 - x1 + 1) * (y2 - y1 + 1)
                let sum = integralSum(integral, width: width, x1: x1, y1: y1, x2: x2, y2: y2)
                let mean = Double(sum) / Double(count)

                let pixelValue = Double(grayscale[y * width + x])
                output[y * width + x] = pixelValue < mean * threshold ? 0 : 255
            }
        }

        return output
    }

    // MARK: - Horizontal Slice Analysis

    /// Extracts a horizontal slice from thresholded image data
    func extractHorizontalSlice(
        _ data: [UInt8],
        width: Int,
        y: Int,
        height sliceHeight: Int
    ) -> [Double] {
        var slice = [Double](repeating: 0, count: width)

        for x in 0..<width {
            var sum: Double = 0
            for dy in 0..<sliceHeight {
                let idx = (y + dy) * width + x
                if idx < data.count {
                    sum += Double(data[idx])
                }
            }
            slice[x] = sum / Double(sliceHeight) / 255.0
        }

        return slice
    }

    /// Finds contiguous dark regions in a horizontal slice
    func findDarkRegions(
        in slice: [Double],
        yPosition: Double,
        minWidth: Int = 3,
        threshold: Double = 0.3
    ) -> [DarkRegion] {
        var regions: [DarkRegion] = []
        var regionStart: Int?
        var regionSum: Double = 0

        for (x, value) in slice.enumerated() {
            let isDark = value < threshold

            if isDark {
                if regionStart == nil {
                    regionStart = x
                    regionSum = 0
                }
                regionSum += value
            } else if let start = regionStart {
                let width = x - start
                if width >= minWidth {
                    let centerX = Double(start) + Double(width) / 2.0
                    let avgIntensity = regionSum / Double(width)
                    regions.append(DarkRegion(
                        centerX: centerX,
                        width: Double(width),
                        averageIntensity: avgIntensity,
                        yPosition: yPosition
                    ))
                }
                regionStart = nil
            }
        }

        // Handle region at end of slice
        if let start = regionStart {
            let width = slice.count - start
            if width >= minWidth {
                let centerX = Double(start) + Double(width) / 2.0
                let avgIntensity = regionSum / Double(width)
                regions.append(DarkRegion(
                    centerX: centerX,
                    width: Double(width),
                    averageIntensity: avgIntensity,
                    yPosition: yPosition
                ))
            }
        }

        return regions
    }

    // MARK: - Texture Metrics

    /// Calculates texture complexity metrics from image data
    func calculateTextureMetrics(
        _ data: [UInt8],
        width: Int,
        height: Int
    ) -> TextureMetrics {
        // Calculate fissure depth (variance of dark regions)
        let darkPixels = data.filter { $0 < 128 }
        let darkRatio = Double(darkPixels.count) / Double(data.count)

        // Calculate fissure density (transitions from light to dark)
        var transitions = 0
        for i in 1..<data.count {
            if (data[i] < 128) != (data[i-1] < 128) {
                transitions += 1
            }
        }
        let density = Double(transitions) / Double(data.count) * 100

        // Calculate pattern regularity using autocorrelation
        let regularity = calculateAutocorrelation(data, width: width, height: height)

        // Calculate dominant orientation (simplified)
        let orientation = calculateDominantOrientation(data, width: width, height: height)

        return TextureMetrics(
            fissureDepth: min(1.0, darkRatio * 2),
            fissureDensity: min(1.0, density),
            patternRegularity: regularity,
            dominantOrientation: orientation
        )
    }

    // MARK: - Private Helpers

    private func computeIntegralImage(_ data: [UInt8], width: Int, height: Int) -> [Int] {
        var integral = [Int](repeating: 0, count: width * height)

        for y in 0..<height {
            var rowSum = 0
            for x in 0..<width {
                rowSum += Int(data[y * width + x])
                let above = y > 0 ? integral[(y - 1) * width + x] : 0
                integral[y * width + x] = rowSum + above
            }
        }

        return integral
    }

    private func integralSum(
        _ integral: [Int],
        width: Int,
        x1: Int, y1: Int,
        x2: Int, y2: Int
    ) -> Int {
        let a = (y1 > 0 && x1 > 0) ? integral[(y1 - 1) * width + (x1 - 1)] : 0
        let b = y1 > 0 ? integral[(y1 - 1) * width + x2] : 0
        let c = x1 > 0 ? integral[y2 * width + (x1 - 1)] : 0
        let d = integral[y2 * width + x2]

        return d - b - c + a
    }

    private func calculateAutocorrelation(
        _ data: [UInt8],
        width: Int,
        height: Int
    ) -> Double {
        // Simplified autocorrelation for pattern regularity
        let lag = 20
        var correlation: Double = 0
        var count = 0

        for y in 0..<height {
            for x in lag..<width {
                let current = Double(data[y * width + x])
                let lagged = Double(data[y * width + x - lag])
                correlation += current * lagged
                count += 1
            }
        }

        let mean = data.reduce(0) { $0 + Int($1) }
        let meanSquared = Double(mean * mean) / Double(data.count * data.count)

        if count > 0 && meanSquared > 0 {
            return min(1.0, (correlation / Double(count)) / (meanSquared * 255 * 255))
        }

        return 0.5
    }

    private func calculateDominantOrientation(
        _ data: [UInt8],
        width: Int,
        height: Int
    ) -> Double {
        // Simplified gradient-based orientation detection
        var horizontalGradient: Double = 0
        var verticalGradient: Double = 0

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let left = Double(data[y * width + x - 1])
                let right = Double(data[y * width + x + 1])
                let top = Double(data[(y - 1) * width + x])
                let bottom = Double(data[(y + 1) * width + x])

                horizontalGradient += abs(right - left)
                verticalGradient += abs(bottom - top)
            }
        }

        // Return orientation in radians (0 = vertical dominant)
        if horizontalGradient + verticalGradient > 0 {
            return atan2(horizontalGradient, verticalGradient)
        }

        return 0
    }
}
