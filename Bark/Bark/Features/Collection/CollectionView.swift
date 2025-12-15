import SwiftUI
import SwiftData

/// Grid view of saved tree scans
struct CollectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TreeScan.dateCaptured, order: .reverse) private var scans: [TreeScan]

    @State private var selectedScan: TreeScan?
    @State private var searchText = ""

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if scans.isEmpty {
                    EmptyCollectionView()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(filteredScans) { scan in
                                TreeCard(scan: scan)
                                    .onTapGesture {
                                        selectedScan = scan
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Collection")
            .searchable(text: $searchText, prompt: "Search trees")
            .sheet(item: $selectedScan) { scan in
                TreeDetailView(scan: scan)
            }
        }
    }

    private var filteredScans: [TreeScan] {
        if searchText.isEmpty {
            return scans
        }
        return scans.filter { scan in
            scan.species.rawValue.localizedCaseInsensitiveContains(searchText) ||
            scan.locationName?.localizedCaseInsensitiveContains(searchText) == true
        }
    }
}

// MARK: - Empty State

struct EmptyCollectionView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Trees Yet", systemImage: "leaf")
        } description: {
            Text("Scan your first tree to start building your collection.")
        }
    }
}

// MARK: - Tree Card

struct TreeCard: View {
    let scan: TreeScan

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Bark image or placeholder
            ZStack {
                if let imageData = scan.barkImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                    Image(systemName: "tree")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(scan.species.rawValue)
                    .font(.headline)
                    .lineLimit(1)

                HStack {
                    Text("~\(scan.ageRange.midpoint) yrs")
                    if scan.locationName != nil {
                        Text("·")
                        Image(systemName: "location.fill")
                            .font(.caption2)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(scan.dateCaptured.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Tree Detail View

struct TreeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let scan: TreeScan

    @State private var isPlaying = false
    @State private var showingDeleteAlert = false
    @State private var showingEditSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Bark image
                    if let imageData = scan.barkImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // Species info
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(scan.species.rawValue)
                                    .font(.title2.bold())
                                Text(scan.species.scientificName)
                                    .font(.subheadline)
                                    .italic()
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: scan.species.isConifer ? "leaf.arrow.triangle.circlepath" : "leaf.fill")
                                .font(.title)
                                .foregroundStyle(.green)
                        }

                        Divider()

                        // Age and metrics
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            MetricView(
                                title: "Age",
                                value: scan.ageRange.displayString,
                                icon: "clock"
                            )

                            MetricView(
                                title: "Category",
                                value: AgeCategory.from(age: scan.ageRange.midpoint, maxAge: scan.species.maxAge).rawValue,
                                icon: "leaf"
                            )

                            if let dbh = scan.dbhCentimeters {
                                MetricView(
                                    title: "Trunk Width",
                                    value: "\(Int(dbh)) cm",
                                    icon: "circle"
                                )
                            }

                            if let complexity = scan.textureComplexity {
                                MetricView(
                                    title: "Bark Complexity",
                                    value: String(format: "%.0f%%", complexity * 100),
                                    icon: "square.stack.3d.up"
                                )
                            }
                        }

                        // Location
                        if let locationName = scan.locationName {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundStyle(.blue)
                                Text(locationName)
                                Spacer()
                            }
                            .font(.subheadline)
                        }

                        // Musical character
                        let voice = SpeciesVoice.voice(for: scan.species)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Musical Character")
                                .font(.headline)

                            Text(voice.character)
                                .foregroundStyle(.secondary)

                            HStack {
                                Label(voice.scale.displayName, systemImage: "music.note")
                                Spacer()
                                Label("Octave \(voice.baseOctave)", systemImage: "dial.low")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                        // Notes
                        if let notes = scan.notes {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes")
                                    .font(.headline)
                                Text(notes)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Bark description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About the Bark")
                                .font(.headline)
                            Text(scan.species.barkDescription)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Fun facts
                        let facts = scan.species.funFacts
                        if !facts.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Did You Know?")
                                    .font(.headline)
                                ForEach(facts, id: \.self) { fact in
                                    HStack(alignment: .top) {
                                        Image(systemName: "sparkle")
                                            .foregroundStyle(.yellow)
                                        Text(fact)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Tree Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingEditSheet = true
                        } label: {
                            Label("Edit Notes", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Delete Tree?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    modelContext.delete(scan)
                    dismiss()
                }
            } message: {
                Text("This will permanently remove this tree from your collection.")
            }
            .sheet(isPresented: $showingEditSheet) {
                EditNotesSheet(scan: scan)
            }
        }
    }
}

// MARK: - Metric View

struct MetricView: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Edit Notes Sheet

struct EditNotesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var scan: TreeScan
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 150)
                }
            }
            .navigationTitle("Edit Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        scan.notes = notes.isEmpty ? nil : notes
                        dismiss()
                    }
                }
            }
            .onAppear {
                notes = scan.notes ?? ""
            }
        }
    }
}

#Preview {
    CollectionView()
        .modelContainer(for: TreeScan.self, inMemory: true)
}
