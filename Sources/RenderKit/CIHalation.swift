import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - CIHalation

class CIHalation: CIFilter {
    // MARK: Lifecycle

    override init() { super.init() }

    @available(*, unavailable) required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Internal

    override var outputImage: CIImage? {
        guard let inputImage, amount > 0 else { return inputImage }

        let scale = min(inputImage.extent.width, inputImage.extent.height) / 1000.0

        let blurredImage = inputImage
            .clampedToExtent()
            .applyingGaussianBlur(sigma: 15 * scale * Double(amount))
            .cropped(to: inputImage.extent)

        return kernel.apply(
            extent: inputImage.extent,
            roiCallback: { $1 },
            arguments: [inputImage, blurredImage]
        )
    }

    @objc dynamic var inputImage: CIImage?
    @objc dynamic var amount: Float = 1

    // MARK: Private

    private let kernel = try! CIKernel.kernels(withMetalString: """
    [[stitchable]] half4 halation(half4 image, half4 blurred) {
        half3 blendColor = half3(0.7, 0.95, 1.0);
        half3 halated = (image.rgb - blurred.rgb) * blendColor;
        half3 result = halated + blurred.rgb;

        return half4(result, image.a);
    }
    """)[0]
}

extension CIFilter {
    static func halation() -> CIHalation { CIHalation() }
}

extension CIImage {
    func applyingHalation(amount: Float = 1) -> CIImage {
        let filter = CIFilter.halation()
        filter.inputImage = self
        filter.amount = amount
        return filter.outputImage!
    }
}
