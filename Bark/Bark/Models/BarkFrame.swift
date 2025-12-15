import Foundation
import QuartzCore

/// Represents a single frame of bark analysis results
struct BarkFrame {
    let timestamp: TimeInterval
    let notes: [NoteEvent]
    let textureMetrics: TextureMetrics

    init(
        timestamp: TimeInterval = CACurrentMediaTime(),
        notes: [NoteEvent] = [],
        textureMetrics: TextureMetrics = TextureMetrics()
    ) {
        self.timestamp = timestamp
        self.notes = notes
        self.textureMetrics = textureMetrics
    }

    /// Returns whether this frame has any notes to play
    var hasNotes: Bool {
        !notes.isEmpty
    }

    /// Returns the average velocity of all notes in this frame
    var averageVelocity: Double {
        guard !notes.isEmpty else { return 0 }
        return Double(notes.reduce(0) { $0 + $1.velocity }) / Double(notes.count)
    }
}

/// Metrics derived from bark texture analysis
struct TextureMetrics {
    /// Depth of fissures (0.0 = smooth, 1.0 = deep cracks)
    let fissureDepth: Double

    /// Number of fissures per unit area (0.0 = none, 1.0 = dense)
    let fissureDensity: Double

    /// How regular/repeating the pattern is (0.0 = chaotic, 1.0 = regular)
    let patternRegularity: Double

    /// Dominant orientation of texture features in radians (0 = vertical)
    let dominantOrientation: Double

    /// Overall complexity score combining all metrics
    var complexity: Double {
        (fissureDepth + fissureDensity + (1 - patternRegularity)) / 3.0
    }

    init(
        fissureDepth: Double = 0.5,
        fissureDensity: Double = 0.5,
        patternRegularity: Double = 0.5,
        dominantOrientation: Double = 0.0
    ) {
        self.fissureDepth = max(0, min(1, fissureDepth))
        self.fissureDensity = max(0, min(1, fissureDensity))
        self.patternRegularity = max(0, min(1, patternRegularity))
        self.dominantOrientation = dominantOrientation
    }
}

/// Represents a contiguous dark region detected in a bark image slice
struct DarkRegion {
    let centerX: Double
    let width: Double
    let averageIntensity: Double  // 0.0 = black, 1.0 = white
    let center: CGPoint

    init(centerX: Double, width: Double, averageIntensity: Double, yPosition: Double) {
        self.centerX = centerX
        self.width = width
        self.averageIntensity = averageIntensity
        self.center = CGPoint(x: centerX, y: yPosition)
    }
}
