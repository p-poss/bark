import SwiftUI
import SwiftData
import ARKit
import SceneKit

/// Main camera and scanning view
struct ScannerView: View {
    @StateObject private var viewModel = ScannerViewModel()
    @State private var showingSaveSheet = false
    @State private var cameraReady = false

    var body: some View {
        ZStack {
            // Black background
            Color.black.ignoresSafeArea()

            // AR Camera preview - only show when camera is configured
            if cameraReady {
                ARCameraPreviewView(session: viewModel.arCameraService.session)
                    .ignoresSafeArea()
            }

            // AR overlay for active notes
            AROverlayView(activeNotes: viewModel.activeNotes)

            // UI overlay
            VStack {
                // LiDAR indicator at top
                if viewModel.isLiDARActive {
                    LiDARIndicator(diameter: viewModel.arCameraService.measuredDiameter)
                        .padding(.top, 60)
                }

                Spacer()

                // Tree info card (when identified)
                if let profile = viewModel.treeProfile {
                    TreeInfoCard(profile: profile, tempo: viewModel.tempo)
                        .padding(.horizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Status indicator
                StatusIndicator(state: viewModel.state)
                    .padding()

                // Control buttons
                ControlBar(
                    state: viewModel.state,
                    isRecording: viewModel.isRecording,
                    recordingDuration: viewModel.recordingDuration,
                    onIdentify: { viewModel.identifyTree() },
                    onPlay: { viewModel.startPlayback() },
                    onRecord: { viewModel.toggleRecording() },
                    onSave: { showingSaveSheet = true }
                )
                .padding(.bottom, 30)
            }
        }
        .task {
            await viewModel.startScanning()
            // Only show camera preview after configuration succeeds
            if case .error = viewModel.state {
                cameraReady = false
            } else {
                cameraReady = true
            }
        }
        .onDisappear {
            viewModel.stopScanning()
        }
        .sheet(isPresented: $showingSaveSheet) {
            if let scan = viewModel.saveCurrentTree() {
                SaveTreeSheet(scan: scan)
            }
        }
    }
}

// MARK: - AR Camera Preview

struct ARCameraPreviewView: UIViewRepresentable {
    let session: ARSession

    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero)
        arView.session = session
        arView.automaticallyUpdatesLighting = true

        // Disable scene rendering - we just want the camera feed
        arView.scene = SCNScene()
        arView.rendersContinuously = true

        return arView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Session is already connected
    }
}

// MARK: - LiDAR Indicator

struct LiDARIndicator: View {
    let diameter: Double?

    var body: some View {
        HStack(spacing: 8) {
            // LiDAR icon with pulse animation
            Image(systemName: "sensor.tag.radiowaves.forward.fill")
                .foregroundStyle(.cyan)
                .symbolEffect(.pulse)

            Text("LiDAR")
                .font(.caption.bold())

            if let diameter = diameter {
                Text("·")
                    .foregroundStyle(.secondary)
                Text(String(format: "%.0f cm", diameter))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - AR Overlay

struct AROverlayView: View {
    let activeNotes: [NoteEvent]

    var body: some View {
        Canvas { context, size in
            for note in activeNotes {
                let screenPosition = CGPoint(
                    x: note.position.x * size.width,
                    y: note.position.y * size.height
                )

                // Color based on pitch
                let hue = note.normalizedPitch
                let color = Color(hue: hue, saturation: 0.7, brightness: 1.0)

                // Size based on velocity
                let baseSize: CGFloat = 30
                let scale = 0.5 + note.normalizedVelocity * 0.5
                let size = baseSize * scale

                // Opacity based on active state
                let opacity = note.isActive ? 0.8 : 0.3

                let rect = CGRect(
                    x: screenPosition.x - size / 2,
                    y: screenPosition.y - size / 2,
                    width: size,
                    height: size
                )

                context.fill(
                    Circle().path(in: rect),
                    with: .color(color.opacity(opacity))
                )

                // Add glow effect
                context.fill(
                    Circle().path(in: rect.insetBy(dx: -5, dy: -5)),
                    with: .color(color.opacity(opacity * 0.3))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Tree Info Card

struct TreeInfoCard: View {
    let profile: TreeProfile
    let tempo: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: profile.species.isConifer ? "leaf.arrow.triangle.circlepath" : "leaf.fill")
                    .foregroundStyle(.green)

                Text(profile.species.rawValue)
                    .font(.headline)

                Spacer()

                Text(profile.confidenceString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("~\(profile.ageRange.midpoint) years")
                Text("·")
                    .foregroundStyle(.secondary)
                Text(profile.ageCategory.rawValue)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Divider()

            HStack {
                Image(systemName: "music.note")
                Text(SpeciesVoice.voice(for: profile.species).scale.displayName)
                Text("·")
                Text("\(Int(tempo)) BPM")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Status Indicator

struct StatusIndicator: View {
    let state: ScannerState

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var statusColor: Color {
        switch state {
        case .initializing, .searching:
            return .yellow
        case .identifying:
            return .orange
        case .identified, .scanning:
            return .green
        case .recording:
            return .red
        case .error:
            return .red
        }
    }

    private var statusText: String {
        switch state {
        case .initializing:
            return "Initializing..."
        case .searching:
            return "Point at tree bark"
        case .identifying:
            return "Identifying species..."
        case .identified:
            return "Tree identified - tap Play"
        case .scanning:
            return "Scanning bark..."
        case .recording:
            return "Recording..."
        case .error(let error):
            return error.message
        }
    }
}

// MARK: - Control Bar

struct ControlBar: View {
    let state: ScannerState
    let isRecording: Bool
    let recordingDuration: TimeInterval
    let onIdentify: () -> Void
    let onPlay: () -> Void
    let onRecord: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            // Save button - fixed width for centering
            Button(action: onSave) {
                VStack {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title2)
                    Text("Save")
                        .font(.caption)
                }
                .frame(width: 60)
            }
            .disabled(state != .scanning && state != .identified(TreeProfile(species: .oak, ageRange: AgeRange(min: 0, max: 0))))
            .opacity(canSave ? 1 : 0.5)

            // Main action button
            Button(action: mainAction) {
                ZStack {
                    Circle()
                        .fill(mainButtonColor)
                        .frame(width: 70, height: 70)

                    if isRecording {
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 80, height: 80)
                    }

                    mainButtonIcon
                        .font(.title)
                        .foregroundStyle(.white)
                }
            }

            // Record button - fixed width for centering
            Button(action: onRecord) {
                VStack {
                    Image(systemName: isRecording ? "stop.fill" : "record.circle")
                        .font(.title2)
                        .foregroundStyle(isRecording ? .red : .primary)
                    Text(isRecording ? formatDuration(recordingDuration) : "Record")
                        .font(.caption)
                }
                .frame(width: 60)
            }
            .disabled(!state.isActive)
            .opacity(state.isActive ? 1 : 0.5)
        }
        .foregroundStyle(.white)
    }

    private var canSave: Bool {
        if case .identified = state { return true }
        if case .scanning = state { return true }
        return false
    }

    private var mainButtonColor: Color {
        switch state {
        case .searching:
            return .blue
        case .identified:
            return .green
        case .scanning, .recording:
            return .orange
        default:
            return .gray
        }
    }

    @ViewBuilder
    private var mainButtonIcon: some View {
        switch state {
        case .searching:
            Image(systemName: "viewfinder")
        case .identifying:
            ProgressView()
                .tint(.white)
        case .identified:
            Image(systemName: "play.fill")
        case .scanning, .recording:
            Image(systemName: "waveform")
        default:
            Image(systemName: "camera")
        }
    }

    private func mainAction() {
        switch state {
        case .searching:
            onIdentify()
        case .identified:
            onPlay()
        default:
            break
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Save Tree Sheet

struct SaveTreeSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let scan: TreeScan
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Species", value: scan.species.rawValue)
                    LabeledContent("Age", value: scan.ageRange.displayString)
                    if let location = scan.locationName {
                        LabeledContent("Location", value: location)
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Save Tree")
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
                        modelContext.insert(scan)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ScannerView()
}
