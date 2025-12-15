import simd

// MARK: - simd_float3 Extensions

extension simd_float3 {
    /// Returns the distance between two points
    func distance(to other: simd_float3) -> Float {
        return simd_distance(self, other)
    }

    /// Returns a normalized version of this vector
    var normalized: simd_float3 {
        return simd_normalize(self)
    }

    /// Returns the length/magnitude of this vector
    var length: Float {
        return simd_length(self)
    }

    /// Returns the dot product with another vector
    func dot(_ other: simd_float3) -> Float {
        return simd_dot(self, other)
    }

    /// Returns the cross product with another vector
    func cross(_ other: simd_float3) -> simd_float3 {
        return simd_cross(self, other)
    }

    /// Linear interpolation to another point
    func lerp(to target: simd_float3, t: Float) -> simd_float3 {
        return simd_mix(self, target, simd_float3(repeating: t))
    }
}

// MARK: - simd_float4x4 Extensions

extension simd_float4x4 {
    /// Returns the translation component of this transform
    var translation: simd_float3 {
        return simd_float3(columns.3.x, columns.3.y, columns.3.z)
    }

    /// Creates a translation matrix
    init(translation: simd_float3) {
        self.init(
            simd_float4(1, 0, 0, 0),
            simd_float4(0, 1, 0, 0),
            simd_float4(0, 0, 1, 0),
            simd_float4(translation.x, translation.y, translation.z, 1)
        )
    }

    /// Creates a scale matrix
    init(scale: simd_float3) {
        self.init(
            simd_float4(scale.x, 0, 0, 0),
            simd_float4(0, scale.y, 0, 0),
            simd_float4(0, 0, scale.z, 0),
            simd_float4(0, 0, 0, 1)
        )
    }

    /// Creates a rotation matrix around the Y axis
    init(rotationY angle: Float) {
        let c = cos(angle)
        let s = sin(angle)
        self.init(
            simd_float4(c, 0, s, 0),
            simd_float4(0, 1, 0, 0),
            simd_float4(-s, 0, c, 0),
            simd_float4(0, 0, 0, 1)
        )
    }
}

// MARK: - Interpolation Helpers

/// Linear interpolation between two values
func lerp<T: FloatingPoint>(_ a: T, _ b: T, _ t: T) -> T {
    return a + (b - a) * t
}

/// Clamps a value to a range
func clamp<T: Comparable>(_ value: T, min: T, max: T) -> T {
    return Swift.max(min, Swift.min(max, value))
}

/// Smoothstep interpolation (ease in/out)
func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
    let t = clamp((x - edge0) / (edge1 - edge0), min: 0, max: 1)
    return t * t * (3 - 2 * t)
}

/// Maps a value from one range to another
func map(_ value: Float, from: ClosedRange<Float>, to: ClosedRange<Float>) -> Float {
    let fromRange = from.upperBound - from.lowerBound
    let toRange = to.upperBound - to.lowerBound
    let normalized = (value - from.lowerBound) / fromRange
    return to.lowerBound + normalized * toRange
}
