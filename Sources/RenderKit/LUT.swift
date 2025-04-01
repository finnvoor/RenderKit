import Accelerate
import Foundation
import CoreImage
#if canImport(UIKit)
import UIKit
#endif

public extension CIImage {
    func applyingLUT(_ lut: LUT, amount: Float = 1) -> CIImage {
        let filter = CIFilter.colorCube()
        filter.cubeData = lut.cubeData
        filter.cubeDimension = lut.cubeDimension
        filter.inputImage = self
        let filteredImage = filter.outputImage!
        if amount < 1 {
            let mix = CIFilter.mix()
            mix.inputImage = filteredImage
            mix.backgroundImage = self
            mix.amount = amount
            return mix.outputImage!
        } else {
            return filteredImage
        }
    }
}

// MARK: - LUT

public struct LUT: Sendable {
    // MARK: Lifecycle

    #if canImport(UIKit)
    @available(iOS 17.0, *) public init?(resource: ImageResource) {
        guard let cgImage = UIImage(resource: resource).cgImage else { return nil }
        self.init(cgImage: cgImage)
    }
    #endif

    public init?(cgImage: CGImage) {
        let pixelCount = cgImage.width * cgImage.height
        cubeDimension = Float(round(pow(Double(cgImage.width * cgImage.height), 1.0 / 3.0)))
        let channelCount = 4
        guard pixelCount == Int(cubeDimension * cubeDimension * cubeDimension) else {
            assertionFailure()
            return nil
        }

        guard let imageData = cgImage.dataProvider?.data,
              let imageDataPointer = CFDataGetBytePtr(imageData) else {
            assertionFailure()
            return nil
        }

        let cubeDataPointer = UnsafeMutablePointer<Float>.allocate(capacity: pixelCount * channelCount)

        vDSP_vfltu8(imageDataPointer, 1, cubeDataPointer, 1, UInt(pixelCount * channelCount))

        var divisor = Float(255.0)
        vDSP_vsdiv(cubeDataPointer, 1, &divisor, cubeDataPointer, 1, UInt(pixelCount * channelCount))

        cubeData = NSData(
            bytesNoCopy: cubeDataPointer,
            length: pixelCount * channelCount * MemoryLayout<Float>.size,
            freeWhenDone: true
        ) as Data
    }

    // MARK: Internal

    let cubeData: Data
    let cubeDimension: Float
}
