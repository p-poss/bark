import Foundation

enum MusicalScale: String, Codable, CaseIterable, Identifiable {
    case major
    case minor
    case dorian
    case phrygian
    case lydian
    case mixolydian
    case locrian
    case majorPentatonic
    case minorPentatonic
    case wholeTone
    case chromatic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .major: return "Major"
        case .minor: return "Natural Minor"
        case .dorian: return "Dorian"
        case .phrygian: return "Phrygian"
        case .lydian: return "Lydian"
        case .mixolydian: return "Mixolydian"
        case .locrian: return "Locrian"
        case .majorPentatonic: return "Major Pentatonic"
        case .minorPentatonic: return "Minor Pentatonic"
        case .wholeTone: return "Whole Tone"
        case .chromatic: return "Chromatic"
        }
    }

    var character: String {
        switch self {
        case .major: return "Bright, happy, triumphant"
        case .minor: return "Sad, mysterious, introspective"
        case .dorian: return "Jazzy, sophisticated, bittersweet"
        case .phrygian: return "Spanish, exotic, dark"
        case .lydian: return "Dreamy, ethereal, hopeful"
        case .mixolydian: return "Bluesy, rock, relaxed"
        case .locrian: return "Unstable, tense, dark"
        case .majorPentatonic: return "Folk, uplifting, simple"
        case .minorPentatonic: return "Bluesy, soulful, Eastern"
        case .wholeTone: return "Dreamy, floating, impressionistic"
        case .chromatic: return "Atonal, complex, modern"
        }
    }

    /// Returns the intervals (semitones from root) for this scale
    func intervals() -> [Int] {
        switch self {
        case .major: return [0, 2, 4, 5, 7, 9, 11]
        case .minor: return [0, 2, 3, 5, 7, 8, 10]
        case .dorian: return [0, 2, 3, 5, 7, 9, 10]
        case .phrygian: return [0, 1, 3, 5, 7, 8, 10]
        case .lydian: return [0, 2, 4, 6, 7, 9, 11]
        case .mixolydian: return [0, 2, 4, 5, 7, 9, 10]
        case .locrian: return [0, 1, 3, 5, 6, 8, 10]
        case .majorPentatonic: return [0, 2, 4, 7, 9]
        case .minorPentatonic: return [0, 3, 5, 7, 10]
        case .wholeTone: return [0, 2, 4, 6, 8, 10]
        case .chromatic: return Array(0...11)
        }
    }

    /// Returns MIDI note numbers for this scale starting at the given root note
    /// - Parameters:
    ///   - root: The root note (default C = 60)
    ///   - octave: The octave to generate notes in (4 = middle C octave)
    /// - Returns: Array of MIDI note numbers
    func midiNotes(root: Int = 60, octave: Int = 4) -> [Int] {
        let baseNote = root + (octave - 4) * 12
        return intervals().map { baseNote + $0 }
    }

    /// Returns MIDI notes spanning multiple octaves
    /// - Parameters:
    ///   - root: The root note
    ///   - octaveRange: Range of octaves to include
    /// - Returns: Array of MIDI note numbers across all octaves
    func midiNotes(root: Int = 60, octaveRange: ClosedRange<Int>) -> [Int] {
        var notes: [Int] = []
        for octave in octaveRange {
            notes.append(contentsOf: midiNotes(root: root, octave: octave))
        }
        return notes.sorted()
    }

    /// Maps a normalized value (0.0-1.0) to a note in this scale
    /// - Parameters:
    ///   - normalizedValue: Value between 0.0 and 1.0
    ///   - root: The root note
    ///   - octaveRange: Range of octaves to map across
    /// - Returns: MIDI note number
    func noteFromNormalized(_ normalizedValue: Double, root: Int = 60, octaveRange: ClosedRange<Int> = 3...5) -> Int {
        let allNotes = midiNotes(root: root, octaveRange: octaveRange)
        let clampedValue = max(0, min(1, normalizedValue))
        let index = Int(clampedValue * Double(allNotes.count - 1))
        return allNotes[index]
    }
}

// MARK: - Note Names

extension MusicalScale {
    /// Common root notes with their MIDI numbers
    enum RootNote: Int, CaseIterable {
        case c = 60
        case cSharp = 61
        case d = 62
        case dSharp = 63
        case e = 64
        case f = 65
        case fSharp = 66
        case g = 67
        case gSharp = 68
        case a = 69
        case aSharp = 70
        case b = 71

        var displayName: String {
            switch self {
            case .c: return "C"
            case .cSharp: return "C#"
            case .d: return "D"
            case .dSharp: return "D#"
            case .e: return "E"
            case .f: return "F"
            case .fSharp: return "F#"
            case .g: return "G"
            case .gSharp: return "G#"
            case .a: return "A"
            case .aSharp: return "A#"
            case .b: return "B"
            }
        }
    }
}
