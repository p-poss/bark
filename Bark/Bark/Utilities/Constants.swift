import Foundation
import CoreGraphics

/// App-wide constants
enum Constants {
    // MARK: - Audio

    enum Audio {
        static let defaultSampleRate: Double = 44100
        static let maxPolyphony = 12
        static let defaultTempo: Double = 80
        static let minTempo: Double = 40
        static let maxTempo: Double = 120
    }

    // MARK: - Camera

    enum Camera {
        static let targetFrameRate = 30
        static let processingFrameRate = 15 // Process every other frame
    }

    // MARK: - Bark Analysis

    enum BarkAnalysis {
        static let sliceHeight = 10
        static let maxNotesPerFrame = 8
        static let minNoteVelocity = 30
        static let darkRegionThreshold: Double = 0.4
        static let minDarkRegionWidth = 5
    }

    // MARK: - LiDAR

    enum LiDAR {
        static let minDepth: Float = 0.2 // meters
        static let maxDepth: Float = 1.5 // meters
        static let depthEdgeThreshold: Float = 0.1 // meters
    }

    // MARK: - Age Estimation

    enum AgeEstimation {
        static let textureModifierRange: Double = 0.4 // ±20%
        static let ageUncertaintyRange: Double = 0.25 // ±25%
    }

    // MARK: - UI

    enum UI {
        static let cardCornerRadius: CGFloat = 16
        static let buttonCornerRadius: CGFloat = 12
        static let noteOverlaySize: CGFloat = 30
        static let animationDuration: Double = 0.3
    }

    // MARK: - Storage

    enum Storage {
        static let maxImageSize: CGFloat = 1920
        static let imageCompressionQuality: CGFloat = 0.8
        static let maxRecordingDuration: TimeInterval = 300 // 5 minutes
    }
}

// MARK: - MIDI Note Helpers

extension Constants {
    /// Standard MIDI note ranges
    enum MIDI {
        static let minNote = 0
        static let maxNote = 127
        static let middleC = 60
        static let a440 = 69

        /// Converts a MIDI note number to frequency in Hz
        static func noteToFrequency(_ note: Int) -> Double {
            440.0 * pow(2.0, Double(note - a440) / 12.0)
        }

        /// Converts frequency to nearest MIDI note number
        static func frequencyToNote(_ frequency: Double) -> Int {
            Int(round(12 * log2(frequency / 440.0) + Double(a440)))
        }

        /// Returns the note name for a MIDI note number
        static func noteName(_ note: Int) -> String {
            let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
            let octave = (note / 12) - 1
            return "\(names[note % 12])\(octave)"
        }
    }
}
