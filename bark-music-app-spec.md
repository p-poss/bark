# Bark: Tree-to-Music iOS App

## Technical Specification Document

**Version:** 1.0  
**Last Updated:** December 2024  
**Author:** Patrick  
**Purpose:** Development reference for Claude Code

---

## 1. Project Overview

### 1.1 Concept

An iOS app that generates unique music from trees by combining three data layers:

1. **Species** → Determines instrument/timbre and musical scale
2. **Age** → Determines tempo, complexity, and tonal depth
3. **Bark Texture** → Real-time note generation from visual scanning

Users point their phone at a tree, the app identifies the species and estimates age, then generates live music as they scan the bark texture.

### 1.2 Target Platform

- **Primary:** iOS 16+ (iPhone 12 Pro and newer with LiDAR)
- **Fallback:** iPhone 11+ without LiDAR (reduced age estimation accuracy)
- **Future:** Android (post-launch)

### 1.3 Core Value Proposition

- Non-destructive (no sensors attached to tree)
- Portable (phone only, no external hardware)
- Educational + artistic (learn species through sound)
- Generative (every scan is unique)

---

## 2. Technical Stack

### 2.1 Languages & Frameworks

```
┌─────────────────────────────────────────────────────────────┐
│ LAYER              │ TECHNOLOGY                             │
├─────────────────────────────────────────────────────────────┤
│ Language           │ Swift 5.9+                             │
│ UI Framework       │ SwiftUI                                │
│ AR/Camera          │ ARKit + AVFoundation                   │
│ Computer Vision    │ Vision framework + Core ML             │
│ 3D/Depth           │ LiDAR via ARKit                        │
│ Audio Engine       │ AudioKit 5.x                           │
│ ML Model Training  │ Create ML (or PyTorch → Core ML)      │
│ Data Persistence   │ SwiftData (iOS 17+) or Core Data      │
│ Networking         │ None required for core features        │
│ Analytics          │ TelemetryDeck (privacy-focused)        │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Key Dependencies

```swift
// Package.swift or SPM dependencies

dependencies: [
    .package(url: "https://github.com/AudioKit/AudioKit", from: "5.6.0"),
    .package(url: "https://github.com/AudioKit/SoundpipeAudioKit", from: "5.6.0"),
    .package(url: "https://github.com/TelemetryDeck/SwiftClient", from: "1.0.0")
]
```

### 2.3 Project Structure

```
Bark/
├── App/
│   ├── BarkApp.swift                 # App entry point
│   └── AppState.swift                # Global app state
│
├── Features/
│   ├── Scanner/
│   │   ├── ScannerView.swift         # Main camera/AR view
│   │   ├── ScannerViewModel.swift    # Scanning logic coordinator
│   │   ├── BarkAnalyzer.swift        # Real-time texture analysis
│   │   └── AROverlayView.swift       # Note visualization overlay
│   │
│   ├── Identification/
│   │   ├── SpeciesClassifier.swift   # Core ML model wrapper
│   │   ├── AgeEstimator.swift        # DBH + texture → age
│   │   └── TreeProfile.swift         # Combined tree data model
│   │
│   ├── Audio/
│   │   ├── AudioEngine.swift         # AudioKit setup/management
│   │   ├── SpeciesVoice.swift        # Per-species instrument config
│   │   ├── AgeModulator.swift        # Age → audio parameters
│   │   ├── NoteGenerator.swift       # Bark data → MIDI events
│   │   └── Voices/
│   │       ├── OakVoice.swift
│   │       ├── BirchVoice.swift
│   │       ├── PineVoice.swift
│   │       └── ... (one per species)
│   │
│   ├── Collection/
│   │   ├── CollectionView.swift      # Saved trees grid
│   │   ├── TreeDetailView.swift      # Individual tree playback
│   │   └── CollectionManager.swift   # CRUD operations
│   │
│   └── Settings/
│       ├── SettingsView.swift
│       └── Preferences.swift
│
├── Models/
│   ├── Species.swift                 # Species enum + metadata
│   ├── TreeScan.swift                # Saved scan data model
│   ├── BarkFrame.swift               # Single frame analysis result
│   └── NoteEvent.swift               # Musical note representation
│
├── Services/
│   ├── CameraService.swift           # AVFoundation camera management
│   ├── LiDARService.swift            # Depth data extraction
│   ├── ImageProcessor.swift          # Metal-accelerated processing
│   └── LocationService.swift         # GPS for collection mapping
│
├── Resources/
│   ├── ML/
│   │   └── BarkClassifier.mlmodel    # Trained species model
│   ├── Audio/
│   │   └── Samples/                  # Instrument samples per species
│   ├── Data/
│   │   └── SpeciesData.json          # Growth rates, metadata
│   └── Assets.xcassets
│
└── Utilities/
    ├── Extensions/
    │   ├── CGImage+Processing.swift
    │   ├── simd+Helpers.swift
    │   └── AudioKit+Extensions.swift
    └── Constants.swift
```

---

## 3. Feature Specifications

### 3.1 Species Identification

**Input:** Bark photograph (cropped to bark region)  
**Output:** Species classification + confidence score  
**Model:** Custom Core ML image classifier

#### Species List (MVP - 20 species)

```swift
enum Species: String, CaseIterable, Codable {
    // Broadleaf
    case oak = "English Oak"
    case beech = "European Beech"
    case ash = "Common Ash"
    case sycamore = "Sycamore"
    case hornbeam = "Hornbeam"
    case sweetChestnut = "Sweet Chestnut"
    case horseChestnut = "Horse Chestnut"
    case silverBirch = "Silver Birch"
    case alder = "Common Alder"
    case willow = "Weeping Willow"
    case poplar = "Black Poplar"
    case lime = "Common Lime"
    case fieldMaple = "Field Maple"
    case wildCherry = "Wild Cherry"
    case rowan = "Rowan"
    
    // Conifer
    case scotsPine = "Scots Pine"
    case yew = "English Yew"
    case larch = "European Larch"
    case douglasFir = "Douglas Fir"
    case norwayspruce = "Norway Spruce"
    
    // Fallback
    case unknownBroadleaf = "Unknown Broadleaf"
    case unknownConifer = "Unknown Conifer"
}
```

#### ML Model Training Plan

```
1. Dataset Collection
   - Source: iNaturalist, Pl@ntNet, custom photography
   - Target: 500+ images per species (bark close-ups)
   - Augmentation: rotation, brightness, crop variations
   
2. Model Architecture
   - Base: MobileNetV3 or EfficientNet-Lite (optimized for mobile)
   - Transfer learning from ImageNet
   - Fine-tune on bark dataset
   
3. Training Pipeline
   - Framework: Create ML (simplest) or PyTorch → coremltools
   - Validation split: 80/10/10 (train/val/test)
   - Target accuracy: >90% top-1, >98% top-3
   
4. Export
   - Format: .mlmodel (Core ML)
   - Quantization: Float16 for size/speed balance
   - Target size: <20MB
```

### 3.2 Age Estimation

**Inputs:**
- Trunk diameter at breast height (DBH) via LiDAR
- Bark texture complexity score
- Species (for growth rate lookup)

**Output:** Age range (e.g., "80-120 years")

#### Algorithm

```swift
struct AgeEstimator {
    
    func estimate(
        species: Species,
        dbhCentimeters: Double,
        textureComplexity: Double  // 0.0 - 1.0
    ) -> AgeRange {
        
        // 1. Base age from DBH using species growth factor
        let growthFactor = species.averageGrowthFactor  // cm diameter per year
        let baseAge = dbhCentimeters / growthFactor
        
        // 2. Adjust based on bark texture (older = more complex)
        // Texture adds ±20% to estimate
        let textureModifier = 1.0 + (textureComplexity - 0.5) * 0.4
        let adjustedAge = baseAge * textureModifier
        
        // 3. Return range (±25% to account for uncertainty)
        let minAge = Int(adjustedAge * 0.75)
        let maxAge = Int(adjustedAge * 1.25)
        
        return AgeRange(min: minAge, max: maxAge, midpoint: Int(adjustedAge))
    }
}

// Growth factors (approximate cm DBH per year)
extension Species {
    var averageGrowthFactor: Double {
        switch self {
        case .oak: return 1.8
        case .beech: return 2.0
        case .ash: return 2.5
        case .silverBirch: return 2.5
        case .scotsPine: return 2.0
        case .yew: return 0.8  // Very slow growing
        case .willow: return 3.5  // Fast growing
        // ... etc
        default: return 2.0
        }
    }
}
```

#### LiDAR DBH Measurement

```swift
class LiDARService {
    
    func measureTrunkDiameter(from frame: ARFrame) -> Double? {
        guard let depthMap = frame.sceneDepth?.depthMap else { return nil }
        
        // 1. Find trunk region (largest vertical surface in center)
        // 2. Sample depth at multiple points across trunk
        // 3. Calculate diameter from depth differential + known camera geometry
        // 4. Return diameter in centimeters
        
        // Implementation uses Metal for real-time depth processing
    }
}
```

### 3.3 Bark Texture Analysis

**Input:** Live camera feed (30fps)  
**Output:** Stream of `BarkFrame` objects containing note trigger data

#### Processing Pipeline

```swift
struct BarkFrame {
    let timestamp: TimeInterval
    let notes: [NoteEvent]
    let textureMetrics: TextureMetrics
}

struct NoteEvent {
    let pitch: Int           // MIDI note number (0-127)
    let velocity: Int        // 0-127
    let duration: TimeInterval
    let position: CGPoint    // Where on screen (for AR overlay)
}

struct TextureMetrics {
    let fissureDepth: Double      // 0.0 - 1.0 (from LiDAR or shadow)
    let fissureDensity: Double    // Fissures per unit area
    let patternRegularity: Double // FFT-derived
    let dominantOrientation: Double // Radians (vertical = 0)
}
```

#### Image Processing Algorithm

```swift
class BarkAnalyzer {
    
    private let context = CIContext(options: [.useSoftwareRenderer: false])
    
    func analyze(pixelBuffer: CVPixelBuffer, depthData: AVDepthData?) -> BarkFrame {
        
        // 1. Convert to grayscale
        let grayscale = applyGrayscaleFilter(pixelBuffer)
        
        // 2. Adaptive thresholding (isolate fissures)
        // Dark regions = fissures, light regions = ridges
        let thresholded = applyAdaptiveThreshold(grayscale, blockSize: 15)
        
        // 3. Horizontal slice analysis
        // Scan image in horizontal bands, each band = one "beat"
        let sliceHeight = 10  // pixels per slice
        var notes: [NoteEvent] = []
        
        for y in stride(from: 0, to: imageHeight, by: sliceHeight) {
            let slice = extractHorizontalSlice(thresholded, y: y, height: sliceHeight)
            
            // Find dark regions (fissures) in this slice
            let darkRegions = findContiguousDarkRegions(slice)
            
            for region in darkRegions {
                // Map horizontal position to pitch (in current scale)
                let normalizedX = region.centerX / imageWidth  // 0.0 - 1.0
                let pitch = mapToScale(normalizedX, scale: currentScale)
                
                // Map region width to duration
                let duration = mapToDuration(region.width)
                
                // Map darkness intensity to velocity
                let velocity = mapToVelocity(region.averageIntensity)
                
                // Add depth data if available (LiDAR)
                let depthBoost = getDepthAtPosition(depthData, region.center)
                
                notes.append(NoteEvent(
                    pitch: pitch + depthBoost,
                    velocity: velocity,
                    duration: duration,
                    position: region.center
                ))
            }
        }
        
        // 4. Calculate overall texture metrics
        let metrics = calculateTextureMetrics(thresholded, depthData)
        
        return BarkFrame(
            timestamp: CACurrentMediaTime(),
            notes: notes,
            textureMetrics: metrics
        )
    }
    
    private func mapToScale(_ normalized: Double, scale: MusicalScale) -> Int {
        // Map 0.0-1.0 to notes within the scale
        // E.g., for D Dorian: D, E, F, G, A, B, C
        let scaleNotes = scale.midiNotes(octave: 4)  // Base octave
        let index = Int(normalized * Double(scaleNotes.count - 1))
        return scaleNotes[index]
    }
}
```

### 3.4 Audio Engine

**Architecture:** AudioKit-based synthesis with per-species instrument voices

#### Audio Graph Structure

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   NoteGenerator (bark frames → MIDI events)                 │
│         │                                                   │
│         ▼                                                   │
│   ┌─────────────────────────────────────────────┐           │
│   │         Species Voice (Sampler/Synth)       │           │
│   │                                             │           │
│   │   Attack, Decay, Sustain, Release           │           │
│   │   Filter cutoff, resonance                  │           │
│   │   Oscillator type / sample bank             │           │
│   └─────────────────┬───────────────────────────┘           │
│                     │                                       │
│                     ▼                                       │
│   ┌─────────────────────────────────────────────┐           │
│   │         Age Modulator (effects chain)       │           │
│   │                                             │           │
│   │   - Reverb (more for older trees)           │           │
│   │   - Low-pass filter (darker for older)      │           │
│   │   - Chorus/ensemble (more voices for older) │           │
│   │   - Tempo scaling                           │           │
│   └─────────────────┬───────────────────────────┘           │
│                     │                                       │
│                     ▼                                       │
│   ┌─────────────────────────────────────────────┐           │
│   │              Master Output                  │           │
│   │                                             │           │
│   │   Limiter → Output                          │           │
│   └─────────────────────────────────────────────┘           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### Species Voice Configuration

```swift
struct SpeciesVoice {
    let species: Species
    let scale: MusicalScale
    let baseOctave: Int
    let instrumentType: InstrumentType
    let attackTime: Double
    let decayTime: Double
    let sustainLevel: Double
    let releaseTime: Double
    let filterCutoff: Double
    let filterResonance: Double
    let reverbMix: Double
    let character: String  // For UI display
}

// Example configurations
extension SpeciesVoice {
    static let oak = SpeciesVoice(
        species: .oak,
        scale: .dorian,
        baseOctave: 3,
        instrumentType: .sampler(bank: "cello_brass"),
        attackTime: 0.1,
        decayTime: 0.3,
        sustainLevel: 0.7,
        releaseTime: 0.5,
        filterCutoff: 2000,
        filterResonance: 0.3,
        reverbMix: 0.4,
        character: "Ancient, grounded, resonant"
    )
    
    static let birch = SpeciesVoice(
        species: .silverBirch,
        scale: .majorPentatonic,
        baseOctave: 5,
        instrumentType: .sampler(bank: "flute_bells"),
        attackTime: 0.02,
        decayTime: 0.2,
        sustainLevel: 0.5,
        releaseTime: 0.3,
        filterCutoff: 8000,
        filterResonance: 0.1,
        reverbMix: 0.3,
        character: "Light, airy, dancing"
    )
    
    static let yew = SpeciesVoice(
        species: .yew,
        scale: .locrian,
        baseOctave: 2,
        instrumentType: .synth(oscillator: .sine, harmonics: [1, 0.5, 0.25]),
        attackTime: 0.5,
        decayTime: 1.0,
        sustainLevel: 0.8,
        releaseTime: 2.0,
        filterCutoff: 800,
        filterResonance: 0.5,
        reverbMix: 0.7,
        character: "Ancient, dark, sacred"
    )
}
```

#### Age Modulation Parameters

```swift
struct AgeModulator {
    
    func modulateVoice(_ voice: SpeciesVoice, forAge age: AgeRange) -> ModulatedVoice {
        
        let ageNormalized = normalizeAge(age.midpoint)  // 0.0 (sapling) to 1.0 (ancient)
        
        return ModulatedVoice(
            baseVoice: voice,
            
            // Tempo: 120 BPM for saplings → 40 BPM for ancient
            tempo: lerp(120, 40, ageNormalized),
            
            // Octave shift: +1 for young, -1 for old
            octaveOffset: Int(lerp(1, -1, ageNormalized)),
            
            // Reverb: dry for young, cathedral for ancient
            reverbMix: lerp(0.1, 0.7, ageNormalized),
            
            // Filter: bright for young, darker for old
            filterCutoff: lerp(8000, 1500, ageNormalized),
            
            // Voice count: 1 for sapling, 5 for ancient
            voiceCount: Int(lerp(1, 5, ageNormalized)),
            
            // Note density: sparse for both young and ancient, dense for mature
            noteDensityMultiplier: bellCurve(ageNormalized, peak: 0.5)
        )
    }
    
    private func normalizeAge(_ age: Int) -> Double {
        // Map age to 0.0-1.0, with 200+ years = 1.0
        return min(Double(age) / 200.0, 1.0)
    }
}
```

### 3.5 AR Overlay

**Purpose:** Visualize which bark features are triggering notes

```swift
struct AROverlayView: View {
    let activeNotes: [NoteEvent]
    
    var body: some View {
        Canvas { context, size in
            for note in activeNotes {
                // Draw glowing circle at note trigger position
                let rect = CGRect(
                    x: note.position.x - 20,
                    y: note.position.y - 20,
                    width: 40,
                    height: 40
                )
                
                // Color based on pitch (low = warm, high = cool)
                let hue = Double(note.pitch - 36) / 72.0  // Map MIDI 36-108 to 0-1
                let color = Color(hue: hue, saturation: 0.7, brightness: 1.0)
                
                // Size based on velocity
                let scale = 0.5 + (Double(note.velocity) / 127.0) * 0.5
                
                // Opacity pulse based on duration
                let opacity = note.isActive ? 0.8 : 0.3
                
                context.fill(
                    Circle().path(in: rect.scaled(by: scale)),
                    with: .color(color.opacity(opacity))
                )
            }
        }
    }
}
```

### 3.6 Data Persistence

**Model:** SwiftData for iOS 17+, Core Data fallback for iOS 16

```swift
@Model
class TreeScan {
    var id: UUID
    var species: Species
    var ageRange: AgeRange
    var location: CLLocationCoordinate2D?
    var locationName: String?
    var dateCaptured: Date
    var barkImageData: Data
    var audioRecordingURL: URL?
    var duration: TimeInterval
    var notes: String?
    
    // Relationships
    @Relationship(deleteRule: .cascade)
    var recordings: [AudioRecording]
}

@Model
class AudioRecording {
    var id: UUID
    var dateCreated: Date
    var duration: TimeInterval
    var fileURL: URL
    var treeScan: TreeScan?
}
```

---

## 4. User Interface Specifications

### 4.1 Navigation Structure

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   Tab Bar Navigation                                        │
│                                                             │
│   ┌─────────┬─────────┬─────────┐                           │
│   │  Scan   │Collection│Settings │                          │
│   │   🎯    │   🌲    │   ⚙️    │                           │
│   └─────────┴─────────┴─────────┘                           │
│                                                             │
│   Scan Tab:                                                 │
│   └── ScannerView (main camera view)                        │
│       └── TreeDetailSheet (after identification)            │
│           └── SaveTreeSheet                                 │
│                                                             │
│   Collection Tab:                                           │
│   └── CollectionView (grid of saved trees)                  │
│       └── TreeDetailView (playback + info)                  │
│           └── EditTreeSheet                                 │
│                                                             │
│   Settings Tab:                                             │
│   └── SettingsView                                          │
│       ├── AudioSettingsView                                 │
│       ├── SpeciesListView                                   │
│       └── AboutView                                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Scanner View Layout

```
┌─────────────────────────────────────────┐
│ Status Bar                              │
├─────────────────────────────────────────┤
│                                         │
│                                         │
│                                         │
│        [Full-screen camera view]        │
│                                         │
│        [AR overlay for active notes]    │
│                                         │
│                                         │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│   ┌─────────────────────────────────┐   │
│   │ 🌳 English Oak                  │   │
│   │ ~140 years · Mature             │   │
│   │                                 │   │
│   │ ♪ D Dorian · 52 BPM             │   │
│   └─────────────────────────────────┘   │
│                                         │
│   [Progress: ████████░░░░ Scanning...]  │
│                                         │
│   ┌─────┐   ┌─────────┐   ┌───────┐     │
│   │     │   │         │   │       │     │
│   │ 💾  │   │   ⏺️    │   │  📤   │     │
│   │Save │   │ Record  │   │ Share │     │
│   └─────┘   └─────────┘   └───────┘     │
│                                         │
└─────────────────────────────────────────┘
```

### 4.3 States

```swift
enum ScannerState {
    case initializing      // Camera starting up
    case searching         // Looking for tree/bark
    case identifying       // ML model running
    case identified(TreeProfile)  // Species + age known
    case scanning          // Generating music
    case recording         // Saving audio
    case error(ScannerError)
}

enum ScannerError {
    case cameraUnavailable
    case lidarUnavailable
    case classificationFailed
    case audioEngineError
}
```

---

## 5. Development Phases

### Phase 1: Foundation (Weeks 1-3)

**Goal:** Basic camera + audio pipeline working

**Tasks:**

```
□ Project setup
  □ Create Xcode project with SwiftUI
  □ Configure AudioKit dependency
  □ Set up folder structure
  
□ Camera pipeline
  □ AVCaptureSession setup
  □ Real-time pixel buffer access
  □ Basic grayscale conversion
  □ Display camera feed in SwiftUI
  
□ Audio engine
  □ AudioKit initialization
  □ Simple synth voice (single oscillator)
  □ MIDI note triggering
  □ Basic ADSR envelope
  
□ Integration
  □ Connect camera brightness → pitch
  □ Verify <100ms latency
  □ Test on device
```

**Deliverable:** App that plays notes based on camera brightness

### Phase 2: Bark Analysis (Weeks 4-6)

**Goal:** Sophisticated texture-to-music mapping

**Tasks:**

```
□ Image processing
  □ Adaptive thresholding
  □ Horizontal slice analysis
  □ Contour detection for fissures
  □ Metal shader optimization
  
□ Musical mapping
  □ Scale quantization
  □ Velocity from intensity
  □ Duration from width
  □ Texture metrics calculation
  
□ Audio refinement
  □ Multiple simultaneous notes
  □ Note limiting (prevent cacophony)
  □ Smoothing between frames
  
□ AR overlay
  □ Basic note position visualization
  □ Color mapping
  □ Animation
```

**Deliverable:** App generates musical patterns from bark texture

### Phase 3: Species & Age (Weeks 7-10)

**Goal:** ML identification and age estimation

**Tasks:**

```
□ Dataset preparation
  □ Collect/curate bark images (500+ per species)
  □ Label and organize dataset
  □ Create train/val/test splits
  □ Augmentation pipeline
  
□ Model training
  □ Set up Create ML project
  □ Train classifier
  □ Evaluate accuracy
  □ Export to Core ML
  
□ Species integration
  □ Load model in app
  □ Run inference on bark region
  □ Display species + confidence
  
□ Age estimation
  □ LiDAR DBH measurement
  □ Growth factor lookup
  □ Texture complexity scoring
  □ Age range calculation
  
□ Species voices
  □ Create 5 initial voice configurations
  □ Sample/synth banks per species
  □ Scale mapping
  
□ Age modulation
  □ Tempo scaling
  □ Reverb/filter curves
  □ Voice layering
```

**Deliverable:** App identifies species, estimates age, plays species-appropriate music

### Phase 4: Polish & Collection (Weeks 11-14)

**Goal:** Complete user experience

**Tasks:**

```
□ Full species support
  □ Expand to 20 species
  □ Voice configuration for each
  □ Accuracy testing
  
□ Collection feature
  □ SwiftData models
  □ Save tree scans
  □ Audio recording
  □ Collection grid view
  □ Playback view
  
□ UI polish
  □ Onboarding flow
  □ Animations and transitions
  □ Error states
  □ Loading states
  
□ Audio polish
  □ Professional sample libraries
  □ Mastering (limiter, EQ)
  □ Spatial audio option
  
□ Performance
  □ Profile and optimize
  □ Memory management
  □ Battery usage
```

**Deliverable:** Feature-complete beta

### Phase 5: Launch Prep (Weeks 15-17)

**Goal:** App Store submission

**Tasks:**

```
□ Testing
  □ TestFlight beta distribution
  □ Bug fixes from feedback
  □ Device compatibility testing
  □ Accessibility audit
  
□ App Store assets
  □ App icon
  □ Screenshots
  □ Preview video
  □ Description copy
  □ Privacy policy
  
□ Submission
  □ App Store Connect setup
  □ Review guidelines compliance
  □ Submit for review
```

---

## 6. Data Files Required

### 6.1 Species Metadata (JSON)

```json
{
  "species": [
    {
      "id": "oak",
      "commonName": "English Oak",
      "scientificName": "Quercus robur",
      "family": "Fagaceae",
      "growthFactorCmPerYear": 1.8,
      "maxAge": 1000,
      "barkDescription": "Deep vertical fissures, grey-brown, very rough",
      "voice": {
        "scale": "dorian",
        "baseOctave": 3,
        "instrumentBank": "cello_brass",
        "attack": 0.1,
        "decay": 0.3,
        "sustain": 0.7,
        "release": 0.5,
        "filterCutoff": 2000,
        "reverbMix": 0.4
      },
      "funFacts": [
        "Can live over 1000 years",
        "Supports over 2000 species of wildlife",
        "Was sacred to Druids"
      ]
    }
    // ... more species
  ]
}
```

### 6.2 Scale Definitions

```swift
enum MusicalScale: String, Codable {
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
    
    func midiNotes(root: Int = 60, octave: Int = 4) -> [Int] {
        let baseNote = root + (octave - 4) * 12
        return intervals().map { baseNote + $0 }
    }
}
```

---

## 7. API Contracts

### 7.1 BarkAnalyzer Protocol

```swift
protocol BarkAnalyzing {
    func analyze(pixelBuffer: CVPixelBuffer, depthData: AVDepthData?) async -> BarkFrame
    func setScale(_ scale: MusicalScale)
    func setOctaveRange(_ range: ClosedRange<Int>)
}
```

### 7.2 AudioEngine Protocol

```swift
protocol AudioEngineProtocol {
    func start() throws
    func stop()
    func setVoice(_ voice: SpeciesVoice)
    func setAgeModulation(_ modulation: AgeModulation)
    func playNotes(_ notes: [NoteEvent])
    func startRecording() -> URL
    func stopRecording()
    var isPlaying: Bool { get }
    var isRecording: Bool { get }
}
```

### 7.3 SpeciesClassifier Protocol

```swift
protocol SpeciesClassifying {
    func classify(image: CGImage) async throws -> ClassificationResult
}

struct ClassificationResult {
    let species: Species
    let confidence: Double
    let alternatives: [(Species, Double)]
}
```

---

## 8. Testing Strategy

### 8.1 Unit Tests

```
□ BarkAnalyzer
  □ Threshold detection accuracy
  □ Scale quantization correctness
  □ Frame rate performance
  
□ AgeEstimator
  □ Growth factor calculations
  □ Edge cases (very young, very old)
  
□ AudioEngine
  □ Note triggering
  □ Voice switching
  □ Modulation curves
```

### 8.2 Integration Tests

```
□ Camera → Analysis → Audio pipeline
□ Species identification → Voice selection
□ Recording and playback
```

### 8.3 Manual Testing Checklist

```
□ Test on 10+ different tree species
□ Test in various lighting conditions
□ Test audio latency perception
□ Test memory usage over extended scanning
□ Test collection with 50+ saved trees
```

---

## 9. Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| Frame analysis latency | <50ms | Time from frame capture to note trigger |
| Audio latency | <30ms | Time from note trigger to sound |
| Species classification | <500ms | Time to display species after pointing |
| Memory usage (scanning) | <200MB | Instruments allocation during scan |
| Memory usage (idle) | <50MB | Background/collection browsing |
| Battery (active scanning) | <15%/hour | Continuous use measurement |
| App launch to ready | <2s | Cold start to camera active |

---

## 10. Future Considerations

### 10.1 Potential V2 Features

- **Forest ensemble mode:** Scan multiple trees, they play together
- **Seasonal variation:** Same tree sounds different in spring vs. autumn
- **Invasive species alerts:** Warning sounds for problematic species
- **Social features:** Share compositions, compare collections
- **Export to DAW:** MIDI export of scanned patterns
- **Apple Watch companion:** Quick species ID from wrist

### 10.2 Technical Debt to Monitor

- ML model size vs. accuracy tradeoff
- Audio sample library storage
- Core Data vs. SwiftData migration path
- iOS version support (16 vs. 17+)

---

## 11. Resources & References

### Documentation

- [AudioKit Documentation](https://audiokit.io/docs/)
- [Core ML Documentation](https://developer.apple.com/documentation/coreml)
- [Vision Framework](https://developer.apple.com/documentation/vision)
- [ARKit LiDAR](https://developer.apple.com/documentation/arkit/arkit_in_ios/content_anchors/visualizing_a_point_cloud_using_scene_depth)

### Datasets

- [iNaturalist Bark Images](https://www.inaturalist.org)
- [Pl@ntNet Dataset](https://plantnet.org)
- [Bark Beetle Gallery Dataset](https://www.kaggle.com/datasets) (for texture reference)

### Audio Libraries

- [AudioKit Cookbook](https://github.com/AudioKit/Cookbook)
- [Freesound](https://freesound.org) (instrument samples, CC licensed)

---

## 12. Open Questions for Development

1. **Sample library sourcing:** Use synthesized sounds initially, or invest in professional samples from the start?

2. **Offline vs. online species ID:** Ship model with app, or use server-side inference for larger model?

3. **LiDAR fallback:** How to handle non-Pro iPhones gracefully?

4. **Localization:** UK species first—how to structure for regional expansion?

5. **Accessibility:** VoiceOver support for species announcements?

---

*This document should be updated as development progresses and decisions are made.*
