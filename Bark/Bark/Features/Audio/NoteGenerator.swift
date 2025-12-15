import Foundation
import Combine

/// Generates and schedules note events from bark analysis data
final class NoteGenerator: ObservableObject {
    @Published var activeNotes: [NoteEvent] = []
    @Published var notesPerSecond: Double = 0

    private var modulatedVoice: ModulatedVoice?
    private var noteHistory: [TimeInterval] = []
    private let maxActiveNotes = 12
    private let noteDecayTime: TimeInterval = 0.5

    private var lastBeatTime: TimeInterval = 0
    private var beatCounter: Int = 0

    // MARK: - Public Methods

    func setVoice(_ voice: ModulatedVoice) {
        modulatedVoice = voice
    }

    /// Processes a bark frame and returns notes to be played
    func processFrame(_ frame: BarkFrame) -> [NoteEvent] {
        guard let voice = modulatedVoice else {
            return frame.notes
        }

        let currentTime = frame.timestamp

        // Apply tempo-based gating
        let beatInterval = voice.beatInterval
        let timeSinceLastBeat = currentTime - lastBeatTime

        // Only trigger notes on beat boundaries
        guard timeSinceLastBeat >= beatInterval else {
            updateActiveNotes(currentTime: currentTime)
            return []
        }

        lastBeatTime = currentTime
        beatCounter += 1

        // Apply note density multiplier
        let maxNotes = Int(Double(frame.notes.count) * voice.noteDensityMultiplier)
        let selectedNotes = selectNotes(from: frame.notes, count: maxNotes, voice: voice)

        // Apply voice count (layer notes)
        let layeredNotes = applyVoiceLayers(to: selectedNotes, voiceCount: voice.voiceCount)

        // Update active notes
        activeNotes.append(contentsOf: layeredNotes)
        updateActiveNotes(currentTime: currentTime)

        // Update statistics
        updateNoteStatistics(currentTime: currentTime, noteCount: layeredNotes.count)

        return layeredNotes
    }

    /// Clears all active notes
    func reset() {
        activeNotes.removeAll()
        noteHistory.removeAll()
        notesPerSecond = 0
        lastBeatTime = 0
        beatCounter = 0
    }

    // MARK: - Private Methods

    private func selectNotes(
        from notes: [NoteEvent],
        count: Int,
        voice: ModulatedVoice
    ) -> [NoteEvent] {
        guard count > 0, !notes.isEmpty else { return [] }

        // Sort by velocity (loudest first) and take top N
        let sorted = notes.sorted { $0.velocity > $1.velocity }
        let selected = Array(sorted.prefix(count))

        // Apply octave offset
        return selected.map { note in
            NoteEvent(
                id: note.id,
                pitch: note.pitch + (voice.octaveOffset * 12),
                velocity: note.velocity,
                duration: note.duration,
                position: note.position,
                timestamp: note.timestamp
            )
        }
    }

    private func applyVoiceLayers(to notes: [NoteEvent], voiceCount: Int) -> [NoteEvent] {
        guard voiceCount > 1 else { return notes }

        var layeredNotes: [NoteEvent] = []

        for note in notes {
            layeredNotes.append(note)

            // Add additional voice layers with slight detuning
            for layer in 1..<voiceCount {
                let detuneAmount = (layer % 2 == 0 ? 1 : -1) * ((layer + 1) / 2)
                let layeredNote = NoteEvent(
                    pitch: note.pitch + (detuneAmount * 12), // Octave layers
                    velocity: note.velocity - (layer * 10), // Slightly quieter
                    duration: note.duration,
                    position: note.position,
                    timestamp: note.timestamp
                )
                if layeredNote.velocity > 20 {
                    layeredNotes.append(layeredNote)
                }
            }
        }

        return layeredNotes
    }

    private func updateActiveNotes(currentTime: TimeInterval) {
        // Remove expired notes
        activeNotes = activeNotes.filter { note in
            let elapsed = currentTime - note.timestamp
            return elapsed < note.duration + noteDecayTime
        }

        // Update isActive status
        activeNotes = activeNotes.map { note in
            var updated = note
            let elapsed = currentTime - note.timestamp
            updated.isActive = elapsed < note.duration
            return updated
        }

        // Limit total active notes
        if activeNotes.count > maxActiveNotes {
            activeNotes = Array(activeNotes.suffix(maxActiveNotes))
        }
    }

    private func updateNoteStatistics(currentTime: TimeInterval, noteCount: Int) {
        // Add current notes to history
        for _ in 0..<noteCount {
            noteHistory.append(currentTime)
        }

        // Remove old history (older than 1 second)
        noteHistory = noteHistory.filter { currentTime - $0 < 1.0 }

        // Calculate notes per second
        notesPerSecond = Double(noteHistory.count)
    }
}

// MARK: - Note Quantization

extension NoteGenerator {
    /// Quantizes note timing to a grid based on tempo
    func quantize(_ note: NoteEvent, to grid: QuantizationGrid, voice: ModulatedVoice) -> NoteEvent {
        let beatInterval = voice.beatInterval
        let gridInterval = beatInterval / Double(grid.divisor)

        let quantizedTimestamp = (note.timestamp / gridInterval).rounded() * gridInterval

        return NoteEvent(
            id: note.id,
            pitch: note.pitch,
            velocity: note.velocity,
            duration: note.duration,
            position: note.position,
            timestamp: quantizedTimestamp
        )
    }
}

/// Grid divisions for note quantization
enum QuantizationGrid: Int, CaseIterable {
    case whole = 1
    case half = 2
    case quarter = 4
    case eighth = 8
    case sixteenth = 16
    case triplet = 3

    var divisor: Int { rawValue }

    var displayName: String {
        switch self {
        case .whole: return "Whole Note"
        case .half: return "Half Note"
        case .quarter: return "Quarter Note"
        case .eighth: return "Eighth Note"
        case .sixteenth: return "Sixteenth Note"
        case .triplet: return "Triplet"
        }
    }
}
