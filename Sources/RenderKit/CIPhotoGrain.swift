import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - CIPhotoGrain

public class CIPhotoGrain: CIFilter {
    // MARK: Lifecycle

    override public init() { super.init() }

    @available(*, unavailable) required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Public

    override public var outputImage: CIImage? {
        let filter = CIFilter(name: "CIPhotoGrain")
        filter?.setValue(inputImage, forKey: kCIInputImageKey)
        filter?.setValue(seed, forKey: "inputSeed")
        filter?.setValue(amount, forKey: "inputAmount")
        filter?.setValue(iso, forKey: "inputISO")
        return filter?.outputImage
    }

    @objc public dynamic var inputImage: CIImage?
    @objc public dynamic var seed: Double = .random(in: 0...1)
    @objc public dynamic var amount: Double = 1
    @objc public dynamic var iso: Double = 10
}

public extension CIFilter {
    static func photoGrain() -> CIPhotoGrain { CIPhotoGrain() }
}

public extension CIImage {
    func applyingPhotoGrain(
        seed: Double = .random(in: 0...1),
        amount: Double = 1,
        iso: Double = 10
    ) -> CIImage {
        let filter = CIFilter.photoGrain()
        filter.inputImage = self
        filter.seed = seed
        filter.amount = amount
        filter.iso = iso
        return filter.outputImage!
    }
}
