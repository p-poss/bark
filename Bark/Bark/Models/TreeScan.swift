import Foundation
import SwiftData
import CoreLocation

@Model
class TreeScan {
    var id: UUID
    var speciesRawValue: String
    var ageMin: Int
    var ageMax: Int
    var ageMidpoint: Int
    var latitude: Double?
    var longitude: Double?
    var locationName: String?
    var dateCaptured: Date
    @Attribute(.externalStorage) var barkImageData: Data?
    var audioRecordingPath: String?
    var duration: TimeInterval
    var notes: String?
    var dbhCentimeters: Double?
    var textureComplexity: Double?

    @Relationship(deleteRule: .cascade, inverse: \AudioRecording.treeScan)
    var recordings: [AudioRecording] = []

    var species: Species {
        get { Species(rawValue: speciesRawValue) ?? .unknownBroadleaf }
        set { speciesRawValue = newValue.rawValue }
    }

    var ageRange: AgeRange {
        get { AgeRange(min: ageMin, max: ageMax, midpoint: ageMidpoint) }
        set {
            ageMin = newValue.min
            ageMax = newValue.max
            ageMidpoint = newValue.midpoint
        }
    }

    var location: CLLocationCoordinate2D? {
        get {
            guard let lat = latitude, let lon = longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        set {
            latitude = newValue?.latitude
            longitude = newValue?.longitude
        }
    }

    init(
        id: UUID = UUID(),
        species: Species,
        ageRange: AgeRange,
        location: CLLocationCoordinate2D? = nil,
        locationName: String? = nil,
        dateCaptured: Date = Date(),
        barkImageData: Data? = nil,
        audioRecordingPath: String? = nil,
        duration: TimeInterval = 0,
        notes: String? = nil,
        dbhCentimeters: Double? = nil,
        textureComplexity: Double? = nil
    ) {
        self.id = id
        self.speciesRawValue = species.rawValue
        self.ageMin = ageRange.min
        self.ageMax = ageRange.max
        self.ageMidpoint = ageRange.midpoint
        self.latitude = location?.latitude
        self.longitude = location?.longitude
        self.locationName = locationName
        self.dateCaptured = dateCaptured
        self.barkImageData = barkImageData
        self.audioRecordingPath = audioRecordingPath
        self.duration = duration
        self.notes = notes
        self.dbhCentimeters = dbhCentimeters
        self.textureComplexity = textureComplexity
    }
}

@Model
class AudioRecording {
    var id: UUID
    var dateCreated: Date
    var duration: TimeInterval
    var filePath: String
    var treeScan: TreeScan?

    var fileURL: URL? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsDirectory?.appendingPathComponent(filePath)
    }

    init(
        id: UUID = UUID(),
        dateCreated: Date = Date(),
        duration: TimeInterval = 0,
        filePath: String
    ) {
        self.id = id
        self.dateCreated = dateCreated
        self.duration = duration
        self.filePath = filePath
    }
}
