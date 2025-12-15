import Foundation
import CoreGraphics
import QuartzCore

/// Represents a musical note event generated from bark analysis
struct NoteEvent: Identifiable, Equatable {
    let id: UUID
    let pitch: Int           // MIDI note number (0-127)
    let velocity: Int        // 0-127
    let duration: TimeInterval
    let position: CGPoint    // Where on screen (for AR overlay)
    let timestamp: TimeInterval

    var isActive: Bool = true

    init(
        id: UUID = UUID(),
        pitch: Int,
        velocity: Int,
        duration: TimeInterval,
        position: CGPoint,
        timestamp: TimeInterval = CACurrentMediaTime()
    ) {
        self.id = id
        self.pitch = clamp(pitch, min: 0, max: 127)
        self.velocity = clamp(velocity, min: 0, max: 127)
        self.duration = max(0, duration)
        self.position = position
        self.timestamp = timestamp
    }

    /// Returns the note name (e.g., "C4", "F#5")
    var noteName: String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (pitch / 12) - 1
        let noteName = noteNames[pitch % 12]
        return "\(noteName)\(octave)"
    }

    /// Returns normalized pitch (0.0-1.0) for visualization
    var normalizedPitch: Double {
        // Map MIDI 36-96 (typical range) to 0-1
        return Double(clamp(pitch, min: 36, max: 96) - 36) / 60.0
    }

    /// Returns normalized velocity (0.0-1.0)
    var normalizedVelocity: Double {
        return Double(velocity) / 127.0
    }
}

// MARK: - Helper

private func clamp(_ value: Int, min minVal: Int, max maxVal: Int) -> Int {
    return max(minVal, min(maxVal, value))
}
