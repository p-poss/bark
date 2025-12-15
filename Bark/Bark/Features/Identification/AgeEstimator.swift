import Foundation

/// Estimates tree age from DBH and texture complexity
struct AgeEstimator {
    /// Estimates age from species, trunk diameter, and bark texture
    /// - Parameters:
    ///   - species: The identified tree species
    ///   - dbhCentimeters: Diameter at breast height in centimeters
    ///   - textureComplexity: Bark texture complexity score (0.0 - 1.0)
    /// - Returns: Estimated age range
    func estimate(
        species: Species,
        dbhCentimeters: Double,
        textureComplexity: Double
    ) -> AgeRange {
        // Base age from DBH using species growth factor
        let growthFactor = species.averageGrowthFactor
        let baseAge = dbhCentimeters / growthFactor

        // Adjust based on bark texture (older = more complex)
        // Texture adds ±20% to estimate
        let textureModifier = 1.0 + (textureComplexity - 0.5) * 0.4
        let adjustedAge = baseAge * textureModifier

        // Return range (±25% to account for uncertainty)
        let minAge = Int(adjustedAge * 0.75)
        let maxAge = Int(adjustedAge * 1.25)

        // Clamp to species max age
        let clampedMax = min(maxAge, species.maxAge)
        let clampedMin = min(minAge, clampedMax)

        return AgeRange(
            min: max(1, clampedMin),
            max: clampedMax,
            midpoint: Int(adjustedAge)
        )
    }

    /// Estimates age using only texture when LiDAR is unavailable
    /// - Parameters:
    ///   - species: The identified tree species
    ///   - textureComplexity: Bark texture complexity score (0.0 - 1.0)
    /// - Returns: Estimated age range (less accurate)
    func estimateFromTextureOnly(
        species: Species,
        textureComplexity: Double
    ) -> AgeRange {
        // Use texture to estimate approximate age bracket
        // This is much less accurate than DBH-based estimation
        let maxAge = Double(species.maxAge)

        // Map texture complexity to age range
        // Young trees have smoother bark, old trees have more complex bark
        let baseAge = textureComplexity * maxAge * 0.6

        // Wider uncertainty range without DBH data
        let minAge = Int(baseAge * 0.5)
        let maxAgeEstimate = Int(baseAge * 1.5)

        return AgeRange(
            min: max(5, minAge),
            max: min(maxAgeEstimate, species.maxAge),
            midpoint: Int(baseAge)
        )
    }

    /// Calculates average DBH from multiple measurements
    /// - Parameter measurements: Array of diameter measurements
    /// - Returns: Average DBH after removing outliers
    func calculateAverageDBH(from measurements: [Double]) -> Double? {
        guard measurements.count >= 3 else {
            return measurements.first
        }

        // Remove outliers using IQR method
        let sorted = measurements.sorted()
        let q1Index = measurements.count / 4
        let q3Index = (measurements.count * 3) / 4
        let q1 = sorted[q1Index]
        let q3 = sorted[q3Index]
        let iqr = q3 - q1

        let lowerBound = q1 - 1.5 * iqr
        let upperBound = q3 + 1.5 * iqr

        let filtered = measurements.filter { $0 >= lowerBound && $0 <= upperBound }

        guard !filtered.isEmpty else {
            return measurements.reduce(0, +) / Double(measurements.count)
        }

        return filtered.reduce(0, +) / Double(filtered.count)
    }
}

// MARK: - Growth Factor Reference

extension AgeEstimator {
    /// Returns growth factor information for educational display
    static func growthFactorInfo(for species: Species) -> String {
        let factor = species.averageGrowthFactor
        let category: String

        switch factor {
        case ..<1.0:
            category = "Very slow growing"
        case 1.0..<1.5:
            category = "Slow growing"
        case 1.5..<2.5:
            category = "Moderate growing"
        case 2.5..<3.5:
            category = "Fast growing"
        default:
            category = "Very fast growing"
        }

        return "\(category) (~\(String(format: "%.1f", factor)) cm diameter per year)"
    }

    /// Returns typical DBH ranges for age brackets
    static func typicalDBH(for species: Species, at age: Int) -> String {
        let factor = species.averageGrowthFactor
        let expectedDBH = Double(age) * factor

        let minDBH = Int(expectedDBH * 0.7)
        let maxDBH = Int(expectedDBH * 1.3)

        return "\(minDBH)-\(maxDBH) cm"
    }
}
