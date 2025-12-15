import SwiftUI

/// App settings and preferences
struct SettingsView: View {
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @AppStorage("showNoteOverlay") private var showNoteOverlay = true
    @AppStorage("autoIdentify") private var autoIdentify = false
    @AppStorage("audioQuality") private var audioQuality = AudioQuality.high

    var body: some View {
        NavigationStack {
            List {
                // Audio Settings
                Section("Audio") {
                    Picker("Recording Quality", selection: $audioQuality) {
                        ForEach(AudioQuality.allCases) { quality in
                            Text(quality.displayName).tag(quality)
                        }
                    }

                    Toggle("Haptic Feedback", isOn: $hapticFeedback)
                }

                // Visual Settings
                Section("Visual") {
                    Toggle("Show Note Overlay", isOn: $showNoteOverlay)
                    Toggle("Auto-identify Trees", isOn: $autoIdentify)
                }

                // Species Library
                Section {
                    NavigationLink {
                        SpeciesListView()
                    } label: {
                        Label("Species Library", systemImage: "leaf.fill")
                    }
                }

                // About
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About Bark", systemImage: "info.circle")
                    }

                    Link(destination: URL(string: "https://github.com/anthropics/claude-code/issues")!) {
                        Label("Send Feedback", systemImage: "envelope")
                    }
                }

                // Version
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Audio Quality

enum AudioQuality: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: return "Low (smaller files)"
        case .medium: return "Medium"
        case .high: return "High (best quality)"
        }
    }

    var sampleRate: Double {
        switch self {
        case .low: return 22050
        case .medium: return 44100
        case .high: return 48000
        }
    }
}

// MARK: - Species List View

struct SpeciesListView: View {
    @State private var searchText = ""
    @State private var filterType: SpeciesFilter = .all

    var body: some View {
        VStack(spacing: 0) {
            // Search bar - always visible at top
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search species", text: $searchText)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 8)

            // Filter picker
            Picker("Filter", selection: $filterType) {
                ForEach(SpeciesFilter.allCases) { filter in
                    Text(filter.displayName).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 12)

            // Species list
            List {
                ForEach(filteredSpecies) { species in
                    NavigationLink {
                        SpeciesDetailView(species: species)
                    } label: {
                        SpeciesRow(species: species)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Species Library")
    }

    private var filteredSpecies: [Species] {
        var species = Species.allCases.filter { $0 != .unknownBroadleaf && $0 != .unknownConifer }

        if filterType != .all {
            species = species.filter { $0.isConifer == (filterType == .conifers) }
        }

        if !searchText.isEmpty {
            species = species.filter {
                $0.rawValue.localizedCaseInsensitiveContains(searchText) ||
                $0.scientificName.localizedCaseInsensitiveContains(searchText)
            }
        }

        return species
    }
}

enum SpeciesFilter: String, CaseIterable, Identifiable {
    case all
    case broadleaf
    case conifers

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All"
        case .broadleaf: return "Broadleaf"
        case .conifers: return "Conifers"
        }
    }
}

// MARK: - Species Row

struct SpeciesRow: View {
    let species: Species

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: species.isConifer ? "leaf.arrow.triangle.circlepath" : "leaf.fill")
                .foregroundStyle(species.isConifer ? .orange : .green)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(species.rawValue)
                    .font(.headline)
                Text(species.scientificName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Species Detail View

struct SpeciesDetailView: View {
    let species: Species

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: species.isConifer ? "leaf.arrow.triangle.circlepath" : "leaf.fill")
                            .font(.largeTitle)
                            .foregroundStyle(species.isConifer ? .orange : .green)

                        VStack(alignment: .leading) {
                            Text(species.rawValue)
                                .font(.title.bold())
                            Text(species.scientificName)
                                .font(.title3)
                                .italic()
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("Family: \(species.family)")
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Bark Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bark Characteristics")
                        .font(.headline)
                    Text(species.barkDescription)
                        .foregroundStyle(.secondary)
                }

                // Growth Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Growth")
                        .font(.headline)

                    HStack {
                        MetricView(
                            title: "Max Age",
                            value: "\(species.maxAge) years",
                            icon: "clock"
                        )
                        MetricView(
                            title: "Growth Rate",
                            value: String(format: "%.1f cm/yr", species.averageGrowthFactor),
                            icon: "arrow.up.right"
                        )
                    }
                }

                // Musical Character
                let voice = SpeciesVoice.voice(for: species)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Musical Voice")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(voice.character)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            VoiceMetric(title: "Scale", value: voice.scale.displayName)
                            VoiceMetric(title: "Octave", value: "\(voice.baseOctave)")
                            VoiceMetric(title: "Attack", value: String(format: "%.2fs", voice.attackTime))
                            VoiceMetric(title: "Reverb", value: String(format: "%.0f%%", voice.reverbMix * 100))
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }

                // Fun Facts
                let facts = species.funFacts
                if !facts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Did You Know?")
                            .font(.headline)

                        ForEach(facts, id: \.self) { fact in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "sparkle")
                                    .foregroundStyle(.yellow)
                                Text(fact)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(species.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct VoiceMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
        }
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App Icon
                Image(systemName: "tree.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)
                    .padding(.top, 40)

                Text("Bark")
                    .font(.largeTitle.bold())

                Text("Transform trees into music")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 16) {
                    Text("How It Works")
                        .font(.title3.bold())

                    AboutItem(
                        icon: "camera.viewfinder",
                        title: "Point",
                        description: "Point your camera at tree bark"
                    )

                    AboutItem(
                        icon: "leaf.fill",
                        title: "Identify",
                        description: "The app identifies the species and estimates age"
                    )

                    AboutItem(
                        icon: "music.note.list",
                        title: "Listen",
                        description: "Unique music is generated from the bark texture"
                    )

                    AboutItem(
                        icon: "square.and.arrow.down",
                        title: "Collect",
                        description: "Save trees to your collection with recordings"
                    )
                }
                .padding()

                Divider()
                    .padding(.horizontal)

                VStack(spacing: 8) {
                    Text("Built with love for trees and music")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Non-destructive · Educational · Generative")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutItem: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    SettingsView()
}
