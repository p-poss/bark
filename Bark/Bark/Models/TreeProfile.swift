import Foundation

/// Combined tree data model containing species, age, and current scan state
struct TreeProfile: Equatable {
    let species: Species
    let confidence: Double
    let ageRange: AgeRange
    let dbhCentimeters: Double?
    let textureComplexity: Double

    init(
        species: Species,
        confidence: Double = 1.0,
        ageRange: AgeRange,
        dbhCentimeters: Double? = nil,
        textureComplexity: Double = 0.5
    ) {
        self.species = species
        self.confidence = confidence
        self.ageRange = ageRange
        self.dbhCentimeters = dbhCentimeters
        self.textureComplexity = textureComplexity
    }

    /// Age category for display purposes
    var ageCategory: AgeCategory {
        AgeCategory.from(age: ageRange.midpoint, maxAge: species.maxAge)
    }

    /// Formatted age string for display
    var ageDisplayString: String {
        if ageRange.min == ageRange.max {
            return "~\(ageRange.midpoint) years"
        }
        return "~\(ageRange.midpoint) years (\(ageRange.min)-\(ageRange.max))"
    }

    /// Confidence as a percentage string
    var confidenceString: String {
        "\(Int(confidence * 100))%"
    }
}

/// Represents an estimated age range for a tree
struct AgeRange: Equatable, Codable {
    let min: Int
    let max: Int
    let midpoint: Int

    init(min: Int, max: Int, midpoint: Int? = nil) {
        self.min = Swift.max(0, min)
        self.max = Swift.max(min, max)
        self.midpoint = midpoint ?? ((min + max) / 2)
    }

    /// Returns a string representation of the range
    var displayString: String {
        if min == max {
            return "\(min) years"
        }
        return "\(min)-\(max) years"
    }
}

/// Categories for tree age for simplified display
enum AgeCategory: String, CaseIterable {
    case sapling = "Sapling"
    case young = "Young"
    case mature = "Mature"
    case old = "Old"
    case ancient = "Ancient"

    static func from(age: Int, maxAge: Int) -> AgeCategory {
        let normalized = Double(age) / Double(maxAge)
        switch normalized {
        case ..<0.05: return .sapling
        case 0.05..<0.2: return .young
        case 0.2..<0.5: return .mature
        case 0.5..<0.8: return .old
        default: return .ancient
        }
    }

    var description: String {
        switch self {
        case .sapling: return "A young seedling just beginning its journey"
        case .young: return "Still growing and establishing itself"
        case .mature: return "In the prime of life, fully established"
        case .old: return "A venerable specimen with many years"
        case .ancient: return "A rare survivor from centuries past"
        }
    }
}

/// Result from species classification
struct ClassificationResult: Equatable {
    let species: Species
    let confidence: Double
    let alternatives: [(Species, Double)]

    init(species: Species, confidence: Double, alternatives: [(Species, Double)] = []) {
        self.species = species
        self.confidence = confidence
        self.alternatives = alternatives
    }

    static func == (lhs: ClassificationResult, rhs: ClassificationResult) -> Bool {
        lhs.species == rhs.species &&
        lhs.confidence == rhs.confidence &&
        lhs.alternatives.count == rhs.alternatives.count
    }
}
