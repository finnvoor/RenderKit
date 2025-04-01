import AVFoundation
import CoreImage
import Foundation
import OSLog

// MARK: - ThumbnailGenerator

@available(iOS 17.0, macOS 14.0, *) actor ThumbnailGenerator {
    // MARK: Internal

    struct ThumbnailStream: Sendable {
        let stream: AsyncStream<CGImage>
        let expectedCount: Int
    }

    nonisolated func generateThumbnails(
        for timeRange: CMTimeRange,
        asset: AVAsset,
        videoComposition: AVVideoComposition? = nil
    ) async throws -> ThumbnailStream? {
        guard !timeRange.isEmpty else { return nil }

        let timePoints = stride(
            from: timeRange.start.seconds,
            to: timeRange.end.seconds,
            by: 1.0
        ).map { CMTime(seconds: $0, preferredTimescale: 600) }

        let expectedCount = timePoints.count

        nonisolated(unsafe) let assetCopy = asset.copy() as! AVAsset
        nonisolated(unsafe) let videoCompositionCopy = videoComposition?.copy() as? AVVideoComposition

        let stream = AsyncStream<CGImage> { @Sendable continuation in
            Task {
                do {
                    let generator = AVAssetImageGenerator(asset: assetCopy)
                    generator.requestedTimeToleranceBefore = .zero
                    generator.requestedTimeToleranceAfter = .zero
                    generator.appliesPreferredTrackTransform = true
                    generator.maximumSize = CGSize(width: 200, height: 200)
                    if let videoCompositionCopy {
                        generator.videoComposition = videoCompositionCopy
                    }

                    for try await image in generator.images(for: timePoints) {
                        try continuation.yield(image.image)
                        await Task.yield()
                    }
                    continuation.finish()
                } catch {
                    logger.error("Failed to generate thumbnails: \(error.localizedDescription)")
                    continuation.finish()
                }
            }
        }

        return ThumbnailStream(stream: stream, expectedCount: expectedCount)
    }

    // MARK: Private

    private let logger = Logger(subsystem: "RenderKit", category: "ThumbnailGenerator")
}
