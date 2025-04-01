import AVFoundation
import Foundation
import OSLog

// MARK: - WaveformData

@available(iOS 17.0, macOS 14.0, *) public struct WaveformData: Sendable {
    // MARK: Public

    public func samplesForScale(_ scale: CGFloat) -> [Float] {
        let targetSamplesPerSecond = Int(200 * min(1, scale))
        return resolutions.first { $0.samplesPerSecond <= targetSamplesPerSecond }?.samples ?? resolutions.last?.samples ?? []
    }

    // MARK: Internal

    let resolutions: [(samplesPerSecond: Int, samples: [Float])]
}

// MARK: - WaveformGenerator

@available(iOS 17.0, macOS 14.0, *) actor WaveformGenerator {
    // MARK: Internal

    nonisolated func generateWaveform(for segment: AVCompositionTrackSegment, asset: AVAsset) async throws -> WaveformData {
        guard !segment.isEmpty else { return WaveformData(resolutions: []) }

        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard let audioTrack = audioTracks.first else { return WaveformData(resolutions: []) }

        let duration = segment.timeMapping.source.duration.seconds
        let resolutions = [200, 100, 50, 25]
        var allSamples: [(Int, [Float])] = []

        for samplesPerSecond in resolutions {
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(
                track: audioTrack,
                outputSettings: [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsNonInterleaved: false
                ]
            )

            reader.add(output)
            reader.timeRange = segment.timeMapping.source

            guard reader.startReading() else {
                logger.error("Failed to start reading at \(samplesPerSecond) samples/sec: \(String(describing: reader.error))")
                continue
            }

            var samples: [Float] = []
            var rmsAccumulator: [Float] = []
            var currentSample = 0

            let samplesPerSegment = Int(duration * Double(samplesPerSecond))
            let audioSampleRate = 44100
            let samplesPerChunk = Int(Double(audioSampleRate) / Double(samplesPerSecond))

            while let sampleBuffer = output.copyNextSampleBuffer() {
                guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }

                var bufferLength = 0
                var bufferData: UnsafeMutablePointer<Int8>?
                CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &bufferLength, dataPointerOut: &bufferData)

                let samples16bit = bufferData?.withMemoryRebound(to: Int16.self, capacity: bufferLength / 2) { ptr in
                    UnsafeBufferPointer(start: ptr, count: bufferLength / 2)
                }

                let frameCount = bufferLength / 2
                let chunkSize = 4096

                for chunkStart in stride(from: 0, to: frameCount, by: chunkSize) {
                    let chunkEnd = min(chunkStart + chunkSize, frameCount)

                    for i in chunkStart..<chunkEnd {
                        let sample = Float(samples16bit?[i] ?? 0) / Float(Int16.max)
                        rmsAccumulator.append(sample * sample)

                        if rmsAccumulator.count >= samplesPerChunk {
                            let rms = sqrt(rmsAccumulator.reduce(0, +) / Float(rmsAccumulator.count))
                            let db = 20 * log10(rms)
                            let normalizedDb = max(0, min(1, (db + 60) / 60))

                            samples.append(normalizedDb)
                            rmsAccumulator.removeAll(keepingCapacity: true)
                            currentSample += 1

                            if currentSample >= samplesPerSegment {
                                break
                            }
                        }
                    }

                    if currentSample >= samplesPerSegment {
                        break
                    }

                    await Task.yield()
                }

                if currentSample >= samplesPerSegment {
                    break
                }
            }

            reader.cancelReading()

            if samples.count > 2 {
                var smoothedSamples: [Float] = []
                smoothedSamples.append(samples[0])

                let smoothingChunkSize = 1000
                for chunkStart in stride(from: 1, to: samples.count - 1, by: smoothingChunkSize) {
                    let chunkEnd = min(chunkStart + smoothingChunkSize, samples.count - 1)
                    for i in chunkStart..<chunkEnd {
                        let smoothed = (samples[i - 1] + samples[i] * 2 + samples[i + 1]) / 4
                        smoothedSamples.append(smoothed)
                    }
                    await Task.yield()
                }

                smoothedSamples.append(samples[samples.count - 1])
                allSamples.append((samplesPerSecond, smoothedSamples))
            } else {
                allSamples.append((samplesPerSecond, samples))
            }

            await Task.yield()
        }

        return WaveformData(resolutions: allSamples)
    }

    // MARK: Private

    private let logger = Logger(subsystem: "RenderKit", category: "WaveformGenerator")
}
