@preconcurrency import AVFoundation
import OSLog
import SwiftUI

// MARK: - CompositionDebugView

@available(iOS 17.0, macOS 14.0, *) public struct CompositionDebugView: View {
    // MARK: Lifecycle

    public init(
        composition: AVComposition,
        videoComposition: AVVideoComposition? = nil,
        audioMix: AVAudioMix? = nil
    ) {
        viewModel = ViewModel(
            composition: composition,
            videoComposition: videoComposition,
            audioMix: audioMix
        )
    }

    // MARK: Public

    public var body: some View {
        VStack(spacing: 0) {
            titleBar

            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 0) {
                    timeMarkers

                    if let videoComposition = viewModel.videoComposition {
                        ZStack(alignment: .topLeading) {
                            ForEach(videoComposition.instructions, id: \.timeRange) { instruction in
                                let width = instruction.timeRange.duration.seconds * viewModel.basePointsPerSecond * scale
                                let offset = instruction.timeRange.start.seconds * viewModel.basePointsPerSecond * scale
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.purple.opacity(0.3))
                                    .frame(width: width, height: 16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .strokeBorder(Color.purple, lineWidth: 1)
                                    )
                                    .overlay(
                                        Text(String(describing: type(of: instruction)))
                                            .font(.system(size: 9))
                                            .lineLimit(1)
                                            .padding(.horizontal, 2)
                                            .shadow(color: .black.opacity(0.5), radius: 2)
                                            .frame(width: width, alignment: .leading)
                                            .offset(y: -2)
                                    )
                                    .offset(x: offset)
                            }
                        }
                        .frame(width: (viewModel.compositionDuration?.seconds ?? 0) * viewModel.basePointsPerSecond * scale, alignment: .leading)
                        .frame(height: 16)
                        .padding(.bottom, 8)
                    }

                    // Preview track
                    let width = (viewModel.compositionDuration?.seconds ?? 0) * viewModel.basePointsPerSecond * scale
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red.opacity(0.3))
                            .frame(width: width, height: 40)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(Color.red, lineWidth: 1)
                            )

                        if let thumbnails = viewModel.previewThumbnails {
                            thumbnailView(
                                thumbnails: thumbnails,
                                width: max(0, width - 2),
                                height: 38
                            ).clipShape(RoundedRectangle(cornerRadius: 3))
                        } else {
                            ProgressView()
                                .scaleEffect(0.5)
                        }

                        Text("Rendered Composition")
                            .font(.system(size: 9))
                            .lineLimit(1)
                            .padding(.horizontal, 2)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                            .frame(width: max(0, width - 2), height: 38, alignment: .topLeading)
                            .offset(y: 2)
                    }
                    .frame(width: width, alignment: .leading)
                    .frame(height: 40)
                    .padding(.bottom, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.tracks) { track in
                            ZStack(alignment: .topLeading) {
                                ForEach(Array(track.segments.enumerated()), id: \.offset) { _, segment in
                                    let width = segment.timeMapping.target.duration.seconds * viewModel.basePointsPerSecond * scale
                                    let offset = segment.timeMapping.target.start.seconds * viewModel.basePointsPerSecond * scale
                                    if !segment.isEmpty {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(trackColor(track).opacity(0.3))
                                                .frame(width: width, height: 40)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .strokeBorder(trackColor(track), lineWidth: 1)
                                                )

                                            if track.mediaType == .video {
                                                if let thumbnails = viewModel.thumbnails[track.id]?[segment] {
                                                    thumbnailView(
                                                        thumbnails: thumbnails,
                                                        width: max(0, width - 2),
                                                        height: 38
                                                    ).clipShape(RoundedRectangle(cornerRadius: 3))
                                                } else {
                                                    ProgressView()
                                                        .scaleEffect(0.5)
                                                        .frame(width: max(0, width - 2), height: 38)
                                                }
                                            } else if track.mediaType == .audio {
                                                if let waveformData = viewModel.waveforms[track.id]?[segment] {
                                                    let samples = waveformData.samplesForScale(scale)
                                                    waveformPath(for: segment, samples: samples, width: max(0, width - 2), height: 38)
                                                        .fill(Color.white.opacity(0.5))
                                                        .frame(width: max(0, width - 2), height: 38)
                                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                                } else {
                                                    ProgressView()
                                                        .scaleEffect(0.5)
                                                        .frame(width: max(0, width - 2), height: 38)
                                                }
                                            }

                                            if let url = segment.sourceURL {
                                                Text(url.lastPathComponent)
                                                    .font(.system(size: 9))
                                                    .lineLimit(1)
                                                    .padding(.horizontal, 2)
                                                    .shadow(color: .black.opacity(0.5), radius: 2)
                                                    .frame(width: max(0, width - 2), height: 38, alignment: .topLeading)
                                                    .offset(y: 2)
                                            }
                                        }
                                        .offset(x: offset)
                                    }
                                }

                                if showAudioMix, track.mediaType == .audio, track.audioMixParameters != nil {
                                    let width = (viewModel.compositionDuration?.seconds ?? 0) * viewModel.basePointsPerSecond * scale
                                    ZStack(alignment: .topLeading) {
                                        volumePath(for: track, width: width, height: 40)
                                            .stroke(Color.white, style: .init(lineWidth: 1.5, lineCap: .round))

                                        ForEach(track.volumePoints) { point in
                                            let x = point.time * viewModel.basePointsPerSecond * scale
                                            let y = 40 * CGFloat(1 - point.volume)
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 4, height: 4)
                                                .position(x: x, y: y)
                                        }
                                    }
                                    .compositingGroup()
                                    .shadow(color: .black.opacity(0.5), radius: 2)
                                }
                            }
                            .frame(width: (viewModel.compositionDuration?.seconds ?? 0) * viewModel.basePointsPerSecond * scale, alignment: .leading)
                            .frame(height: 40)
                        }
                    }
                }
                .padding(8)
            }
            .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = max(0.1, min(10.0, lastScale * value))
                    }
                    .onEnded { _ in
                        lastScale = scale
                    }
            )
        }
        .task {
            do {
                try await viewModel.loadTracks()
            } catch {
                logger.error("Failed to load tracks: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Private

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var showAudioMix: Bool = true

    private let logger = Logger(subsystem: "RenderKit", category: "CompositionDebugView")

    private let viewModel: ViewModel

    private var titleBar: some View {
        HStack {
            if let duration = viewModel.compositionDuration {
                Text(Duration.seconds(duration.seconds), format: .time(pattern: .minuteSecond))
            }
            if let size = viewModel.naturalSize {
                Text("(\(Int(size.width).description)×\(Int(size.height).description))")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if viewModel.hasAudioMix {
                Toggle(isOn: $showAudioMix) {
                    Label("Toggle Audio Mix", systemImage: "chart.xyaxis.line")
                        .labelStyle(.iconOnly)
                }
                .toggleStyle(.button)
                .controlSize(.small)
            }
        }
        .font(.system(size: 12))
        .padding(.bottom, 4)
        .background(.bar)
    }

    private var timeMarkers: some View {
        let duration = viewModel.compositionDuration?.seconds ?? 0
        let markerSpacing: CGFloat = max(1, floor(1 / scale))
        let times = Array(stride(from: 0.0, through: duration, by: Double(markerSpacing)))

        return ZStack(alignment: .topLeading) {
            ForEach(times, id: \.self) { time in
                let xPos = time * viewModel.basePointsPerSecond * scale
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 1, height: 8)
                    Text(Duration.seconds(time), format: .time(pattern: .minuteSecond))
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .offset(x: xPos)
            }
        }
        .frame(height: 24)
    }

    private func thumbnailView(
        thumbnails: ViewModel.Thumbnails,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        ThumbnailStreamView(
            thumbnails: thumbnails.images,
            expectedCount: thumbnails.expectedCount,
            width: width,
            height: height
        )
    }
}

// MARK: - ThumbnailStreamView

@available(iOS 17.0, macOS 14.0, *) private struct ThumbnailStreamView: View {
    let thumbnails: [CGImage]
    let expectedCount: Int
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let thumbnailWidth = width / CGFloat(max(1, expectedCount))

        ZStack(alignment: .leading) {
            ForEach(Array(thumbnails.enumerated()), id: \.offset) { index, thumbnail in
                let xOffset = thumbnailWidth * CGFloat(index)

                Image(thumbnail, scale: 1.0, label: Text(""))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: thumbnailWidth, height: height)
                    .clipped()
                    .offset(x: xOffset)
            }
        }
        .frame(width: width, alignment: .leading)
    }
}

@available(iOS 17.0, macOS 14.0, *) extension CompositionDebugView {
    struct Track: Identifiable {
        // MARK: Lifecycle

        init(
            id: CMPersistentTrackID,
            segments: [AVCompositionTrackSegment],
            mediaType: AVMediaType,
            audioMixParameters: AVAudioMixInputParameters?,
            waveformSamples: [AVCompositionTrackSegment: [Float]] = [:],
            thumbnails: [AVCompositionTrackSegment: ThumbnailGenerator.ThumbnailStream] = [:],
            compositionDuration: CMTime
        ) {
            self.id = id
            self.segments = segments
            self.mediaType = mediaType
            self.audioMixParameters = audioMixParameters
            self.waveformSamples = waveformSamples
            self.thumbnails = thumbnails
            self.compositionDuration = compositionDuration
        }

        // MARK: Internal

        struct VolumePoint: Identifiable, Hashable {
            let id = UUID()
            let time: Double
            let volume: Float
        }

        let id: CMPersistentTrackID
        let segments: [AVCompositionTrackSegment]
        let mediaType: AVMediaType
        let audioMixParameters: AVAudioMixInputParameters?
        let waveformSamples: [AVCompositionTrackSegment: [Float]]
        let thumbnails: [AVCompositionTrackSegment: ThumbnailGenerator.ThumbnailStream]

        let compositionDuration: CMTime

        var volumePoints: [VolumePoint] {
            guard let params = audioMixParameters else { return [] }
            var points: [VolumePoint] = []

            var startTime = CMTime.zero
            var startVolume: Float = 0
            var endVolume: Float = 1.0
            var timeRange = CMTimeRange()
            let trackEnd = compositionDuration.seconds

            while params.getVolumeRamp(
                for: startTime,
                startVolume: &startVolume,
                endVolume: &endVolume,
                timeRange: &timeRange
            ) {
                if points.isEmpty, timeRange.start > .zero {
                    points.append(VolumePoint(time: 0, volume: startVolume))
                }
                points.append(VolumePoint(time: timeRange.start.seconds, volume: startVolume))
                let endTime = timeRange.end.seconds.isInfinite ? trackEnd : timeRange.end.seconds
                points.append(VolumePoint(time: endTime, volume: endVolume))
                startTime = timeRange.end
            }

            if points.isEmpty {
                points.append(VolumePoint(time: 0, volume: 1.0))
                points.append(VolumePoint(time: trackEnd, volume: 1.0))
            } else if let lastPoint = points.last, lastPoint.time < trackEnd {
                points.append(VolumePoint(time: trackEnd, volume: lastPoint.volume))
            }

            return points
        }
    }

    private func volumePath(for track: Track, width _: CGFloat, height: CGFloat) -> Path {
        Path { path in
            let points = track.volumePoints
            guard !points.isEmpty else { return }

            var firstPoint = true
            for point in points {
                let x = point.time * viewModel.basePointsPerSecond * scale
                let y = height * CGFloat(1 - point.volume)

                if firstPoint {
                    path.move(to: CGPoint(x: x, y: y))
                    firstPoint = false
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }

    private func waveformPath(for _: AVCompositionTrackSegment, samples: [Float], width: CGFloat, height: CGFloat) -> Path {
        Path { path in
            guard !samples.isEmpty else { return }

            let stepX = width / CGFloat(samples.count - 1)
            let maxPoints = Int(width)
            let stride = max(1, samples.count / maxPoints)

            path.move(to: CGPoint(x: 0, y: height))

            var index = 0
            while index < samples.count {
                let x = CGFloat(index) * stepX
                let y = height * (1 - CGFloat(samples[index]))
                path.addLine(to: CGPoint(x: x, y: y))
                index += stride
            }

            if let lastIndex = samples.indices.last {
                let x = width
                let y = height * (1 - CGFloat(samples[lastIndex]))
                path.addLine(to: CGPoint(x: x, y: y))
            }

            path.addLine(to: CGPoint(x: width, y: height))
            path.closeSubpath()
        }
    }

    @Observable @MainActor class ViewModel {
        // MARK: Lifecycle

        init(
            composition: AVComposition,
            videoComposition: AVVideoComposition? = nil,
            audioMix: AVAudioMix? = nil
        ) {
            self.composition = composition
            self.videoComposition = videoComposition
            self.audioMix = audioMix
        }

        // MARK: Internal

        struct Thumbnails: Sendable {
            let images: [CGImage]
            let expectedCount: Int
        }

        var compositionDuration: CMTime? = nil
        var naturalSize: CGSize? = nil
        var tracks: [Track] = []
        let videoComposition: AVVideoComposition?
        private(set) var waveforms: [CMPersistentTrackID: [AVCompositionTrackSegment: WaveformData]] = [:]
        private(set) var thumbnails: [CMPersistentTrackID: [AVCompositionTrackSegment: Thumbnails]] = [:]
        private(set) var previewThumbnails: Thumbnails? = nil
        let basePointsPerSecond: CGFloat = 100

        var hasAudioMix: Bool {
            audioMix != nil && tracks.contains { $0.mediaType == .audio }
        }

        func loadTracks() async throws {
            compositionDuration = try await composition.load(.duration)
            let compositionTracks = try await composition.load(.tracks)

            if let videoComposition {
                naturalSize = videoComposition.renderSize
            } else if let videoTrack = compositionTracks.first(where: { $0.mediaType == .video }) {
                naturalSize = try await videoTrack.load(.naturalSize)
            }

            var tracks: [Track] = []
            for track in compositionTracks {
                let segments = try await track.load(.segments) as! [AVCompositionTrackSegment]
                let audioParams = audioMix?.inputParameters.first {
                    $0.trackID == track.trackID
                }

                tracks.append(Track(
                    id: track.trackID,
                    segments: segments,
                    mediaType: track.mediaType,
                    audioMixParameters: audioParams,
                    compositionDuration: compositionDuration!
                ))
            }

            tracks.sort { track1, track2 in
                switch (track1.mediaType, track2.mediaType) {
                case (.video, .audio): true
                case (.audio, .video): false
                default: track1.id < track2.id
                }
            }

            self.tracks = tracks

            async let waveforms = await loadWaveforms()
            func loadAllThumbnails() async {
                await loadThumbnails()
                await loadPreviewThumbnails()
            }
            async let thumbnails = await loadAllThumbnails()

            await (waveforms, thumbnails)
        }

        // MARK: Private

        private let composition: AVComposition
        private let audioMix: AVAudioMix?
        private let logger = Logger(subsystem: "RenderKit", category: "CompositionDebugView")

        @MainActor private func updateWaveform(_ result: (CMPersistentTrackID, AVCompositionTrackSegment, WaveformData)) {
            let (trackId, segment, waveform) = result
            if waveforms[trackId] == nil {
                waveforms[trackId] = [:]
            }
            waveforms[trackId]?[segment] = waveform
        }

        @MainActor private func updateThumbnail(
            _ result: (
                CMPersistentTrackID,
                AVCompositionTrackSegment,
                ThumbnailGenerator.ThumbnailStream
            )
        ) async {
            let (trackId, segment, thumbnails) = result
            if self.thumbnails[trackId] == nil {
                self.thumbnails[trackId] = [:]
            }

            var images: [CGImage] = []
            for await thumbnail in thumbnails.stream {
                guard !Task.isCancelled else { return }
                images.append(thumbnail)
                self.thumbnails[trackId]?[segment] = .init(
                    images: images,
                    expectedCount: thumbnails.expectedCount
                )
            }
        }

        private func loadWaveforms() async {
            let generator = WaveformGenerator()

            let audioTracks = tracks.filter { $0.mediaType == .audio }

            for track in audioTracks {
                let trackId = track.id
                for segment in track.segments where !segment.isEmpty {
                    guard !Task.isCancelled else { return }
                    if let url = segment.sourceURL {
                        let asset = AVURLAsset(url: url)

                        do {
                            let waveform = try await generator.generateWaveform(for: segment, asset: asset)
                            updateWaveform((trackId, segment, waveform))
                        } catch {
                            logger.error("Failed to generate waveform: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }

        private func loadThumbnails() async {
            let generator = ThumbnailGenerator()

            let videoTracks = tracks.filter { $0.mediaType == .video }

            let maxConcurrentTasks = 2
            var activeTasks = 0

            for track in videoTracks {
                let trackId = track.id
                for segment in track.segments where !segment.isEmpty {
                    guard !Task.isCancelled else { return }
                    if let url = segment.sourceURL {
                        let asset = AVURLAsset(url: url)

                        do {
                            if let thumbnail = try await generator.generateThumbnails(
                                for: segment.timeMapping.source,
                                asset: asset
                            ) {
                                await updateThumbnail((trackId, segment, thumbnail))
                            }
                        } catch {
                            logger.error("Failed to generate thumbnail: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }

        private func loadPreviewThumbnails() async {
            guard let duration = compositionDuration else { return }

            let generator = ThumbnailGenerator()

            do {
                nonisolated(unsafe) let videoComposition = videoComposition?.copy() as? AVVideoComposition
                guard let thumbnails = try await generator.generateThumbnails(
                    for: CMTimeRange(start: .zero, duration: duration),
                    asset: composition,
                    videoComposition: videoComposition
                ) else { return }

                var images: [CGImage] = []
                for await thumbnail in thumbnails.stream {
                    images.append(thumbnail)
                    await MainActor.run {
                        previewThumbnails = .init(
                            images: images,
                            expectedCount: thumbnails.expectedCount
                        )
                    }
                }
            } catch {
                logger.error("Failed to generate preview thumbnails: \(error.localizedDescription)")
            }
        }
    }
}

@available(iOS 17.0, macOS 14.0, *) extension CompositionDebugView {
    private func trackColor(_ track: Track) -> Color {
        track.mediaType == .audio ? .green : .blue
    }
}
