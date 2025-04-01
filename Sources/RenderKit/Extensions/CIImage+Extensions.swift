import CoreImage
import CoreImage.CIFilterBuiltins
#if canImport(UIKit)
import UIKit

public extension CIImage {
    @available(iOS 17.0, *) convenience init?(resource: ImageResource) {
        self.init(image: UIImage(resource: resource))
    }
}
#endif

public extension CIImage {
    /// Resizes the image to fit or fill within a given rectangle using the specified content mode.
    /// - Parameters:
    ///   - rect: The target rectangle to fit or fill the image into.
    ///   - contentMode: The content mode to use, either `.aspectFit` or `.aspectFill`.
    /// - Returns: A new `CIImage` scaled to fit within the specified rectangle.
    func resized(to rect: CGRect, contentMode: ContentMode = .scaleAspectFit) -> CIImage {
        guard rect.width > 0, rect.height > 0 else { return .empty() }

        let imageAspectRatio = extent.width / extent.height
        let targetAspectRatio = rect.width / rect.height

        let scale: CGSize

        switch contentMode {
        case .scaleToFill:
            scale = CGSize(
                width: rect.width / extent.width,
                height: rect.height / extent.height
            )
        case .scaleAspectFit:
            let _scale = targetAspectRatio > imageAspectRatio
                ? rect.height / extent.height
                : rect.width / extent.width
            scale = CGSize(width: _scale, height: _scale)
        case .scaleAspectFill:
            let _scale = targetAspectRatio > imageAspectRatio
                ? rect.width / extent.width
                : rect.height / extent.height
            scale = CGSize(width: _scale, height: _scale)
        }

        let newWidth = extent.width * scale.width
        let newHeight = extent.height * scale.height

        let xOffset = rect.origin.x + (rect.width - newWidth) / 2
        let yOffset = rect.origin.y + (rect.height - newHeight) / 2
        let transform = CGAffineTransform(
            scaleX: scale.width,
            y: scale.height
        ).translatedBy(
            x: xOffset / scale.width - extent.origin.x,
            y: yOffset / scale.height - extent.origin.y
        )

        return transformed(by: transform)
            .cropped(to: rect)
    }

    /// Content mode options for image resizing.
    enum ContentMode {
        /// The option to scale the image to fit the size by changing the aspect ratio if necessary.
        case scaleToFill
        /// The option to scale the image to fit the size by maintaining the aspect ratio. Any remaining area of the bounds is transparent.
        case scaleAspectFit
        /// The option to scale the image to fill the size. Some portion of the image may be clipped to fill the bounds.
        case scaleAspectFill
    }

    func translated(by offset: CGPoint) -> CIImage {
        transformed(by: .init(translationX: offset.x, y: offset.y))
    }

    func translated(x: CGFloat = 0, y: CGFloat = 0) -> CIImage {
        transformed(by: .init(translationX: x, y: y))
    }

    func moved(to origin: CGPoint) -> CIImage {
        translated(by: origin - extent.origin)
    }

    func rotated(byRadians angle: CGFloat) -> CIImage {
        transformed(by: .init(rotationAngle: angle))
    }

    func rotated(byDegrees angle: CGFloat) -> CIImage {
        rotated(byRadians: angle * .pi / 180)
    }

    func scaled(by scale: CGFloat) -> CIImage {
        scaled(scaleX: scale, y: scale)
    }

    func scaled(scaleX: CGFloat = 1, y: CGFloat = 1) -> CIImage {
        transformed(by: .init(scaleX: scaleX, y: y))
    }
}

public extension CIImage {
    func composited(over background: CIImage, using blendKernel: CIBlendKernel) -> CIImage {
        blendKernel.apply(foreground: self, background: background) ?? self
    }

    func applyingThreshold(_ threshold: Float = 0.5) -> CIImage {
        let filter = CIFilter.colorThreshold()
        filter.inputImage = self
        filter.threshold = threshold
        return filter.outputImage!
    }

    func applyingBokehBlur(
        radius: Float = 20,
        ringAmount: Float = 0,
        ringSize: Float = 0.1,
        softness: Float = 1
    ) -> CIImage {
        let filter = CIFilter.bokehBlur()
        filter.inputImage = self
        filter.radius = radius
        filter.ringAmount = ringAmount
        filter.ringSize = ringSize
        filter.softness = softness
        return filter.outputImage!
    }

    func applyingColorMatrix(
        rVector: CIVector = .init(x: 1, y: 0, z: 0, w: 0),
        gVector: CIVector = .init(x: 0, y: 1, z: 0, w: 0),
        bVector: CIVector = .init(x: 0, y: 0, z: 1, w: 0),
        aVector: CIVector = .init(x: 0, y: 0, z: 0, w: 1),
        biasVector: CIVector = .zero
    ) -> CIImage {
        let filter = CIFilter.colorMatrix()
        filter.inputImage = self
        filter.rVector = rVector
        filter.gVector = gVector
        filter.bVector = bVector
        filter.aVector = aVector
        filter.biasVector = biasVector
        return filter.outputImage!
    }

    func applyingMotionBlur(radius: Float, angle: Float = 0) -> CIImage {
        let filter = CIFilter.motionBlur()
        filter.inputImage = self
        filter.radius = radius
        filter.angle = angle
        return filter.outputImage!
    }

    func yCbCr() -> (luma: CIImage, chrominance: CIImage) {
        let luma = applyingColorMatrix(
            rVector: CIVector(x: 0.299, y: 0.587, z: 0.114, w: 0),
            gVector: CIVector(x: 0.299, y: 0.587, z: 0.114, w: 0),
            bVector: CIVector(x: 0.299, y: 0.587, z: 0.114, w: 0)
        )
        let chrominance = composited(over: luma, using: .componentAdd)
        return (luma, chrominance)
    }

    func yIQ() -> (luma: CIImage, chrominance: CIImage) {
        let luma = applyingColorMatrix(
            rVector: CIVector(x: 0.2989, y: 0.5959, z: 0.2115, w: 0),
            gVector: CIVector(x: 0.5870, y: -0.2744, z: -0.5229, w: 0),
            bVector: CIVector(x: 0.1140, y: -0.3216, z: 0.3114, w: 0)
        )
        let chrominance = composited(over: luma, using: .componentAdd)
        return (luma, chrominance)
    }

    func applyingVibrance(_ amount: CGFloat) -> CIImage {
        let filter = CIFilter.vibrance()
        filter.inputImage = self
        filter.amount = Float(amount)
        return filter.outputImage!
    }

    func applyingTemperature(neutral: CIVector, targetNeutral: CIVector) -> CIImage {
        let filter = CIFilter.temperatureAndTint()
        filter.inputImage = self
        filter.neutral = neutral
        filter.targetNeutral = targetNeutral
        return filter.outputImage!
    }

    func applyingBloom(radius: Float, intensity: Float) -> CIImage {
        let filter = CIFilter.bloom()
        filter.inputImage = self
        filter.radius = radius
        filter.intensity = intensity
        return filter.outputImage!
    }

    func applyingUnsharpMask(radius: Double, intensity: Double) -> CIImage {
        let filter = CIFilter.unsharpMask()
        filter.inputImage = self
        filter.radius = Float(radius)
        filter.intensity = Float(intensity)
        return filter.outputImage!
    }

    func applyingColorControls(
        brightness: Float = 0.0,
        contrast: Float = 1.0,
        saturation: Float = 1.0
    ) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = self
        filter.brightness = brightness
        filter.contrast = contrast
        filter.saturation = saturation
        return filter.outputImage!
    }

    func applyingExposureAdjust(_ ev: Float) -> CIImage {
        let filter = CIFilter.exposureAdjust()
        filter.inputImage = self
        filter.ev = ev
        return filter.outputImage!
    }

    func applyingGammaAdjust(_ power: Float) -> CIImage {
        let filter = CIFilter.gammaAdjust()
        filter.inputImage = self
        filter.power = power
        return filter.outputImage!
    }

    func applyingHueAdjust(_ angle: Float) -> CIImage {
        let filter = CIFilter.hueAdjust()
        filter.inputImage = self
        filter.angle = angle
        return filter.outputImage!
    }

    func applyingSepiaTone(_ intensity: Float = 1.0) -> CIImage {
        let filter = CIFilter.sepiaTone()
        filter.inputImage = self
        filter.intensity = intensity
        return filter.outputImage!
    }

    func applyingVignette(radius: Float = 1.0, intensity: Float = 0.0) -> CIImage {
        let filter = CIFilter.vignette()
        filter.inputImage = self
        filter.radius = radius
        filter.intensity = intensity
        return filter.outputImage!
    }

    func applyingNoiseReduction(noiseLevel: Float = 0.02, sharpness: Float = 0.4) -> CIImage {
        let filter = CIFilter.noiseReduction()
        filter.inputImage = self
        filter.noiseLevel = noiseLevel
        filter.sharpness = sharpness
        return filter.outputImage!
    }

    func applyingHighlightShadowAdjust(
        highlightAmount: Float = 1.0,
        shadowAmount: Float = 0.0
    ) -> CIImage {
        let filter = CIFilter.highlightShadowAdjust()
        filter.inputImage = self
        filter.highlightAmount = highlightAmount
        filter.shadowAmount = shadowAmount
        return filter.outputImage!
    }

    func applyingColorMonochrome(
        color: CIColor = .white,
        intensity: Float = 1.0
    ) -> CIImage {
        let filter = CIFilter.colorMonochrome()
        filter.inputImage = self
        filter.color = color
        filter.intensity = intensity
        return filter.outputImage!
    }

    func applyingPhotoEffectChrome() -> CIImage {
        let filter = CIFilter.photoEffectChrome()
        filter.inputImage = self
        return filter.outputImage!
    }

    func applyingPhotoEffectFade() -> CIImage {
        let filter = CIFilter.photoEffectFade()
        filter.inputImage = self
        return filter.outputImage!
    }

    func applyingPhotoEffectInstant() -> CIImage {
        let filter = CIFilter.photoEffectInstant()
        filter.inputImage = self
        return filter.outputImage!
    }

    func applyingPhotoEffectMono() -> CIImage {
        let filter = CIFilter.photoEffectMono()
        filter.inputImage = self
        return filter.outputImage!
    }

    func applyingPhotoEffectNoir() -> CIImage {
        let filter = CIFilter.photoEffectNoir()
        filter.inputImage = self
        return filter.outputImage!
    }

    func applyingPhotoEffectProcess() -> CIImage {
        let filter = CIFilter.photoEffectProcess()
        filter.inputImage = self
        return filter.outputImage!
    }

    func applyingPhotoEffectTonal() -> CIImage {
        let filter = CIFilter.photoEffectTonal()
        filter.inputImage = self
        return filter.outputImage!
    }

    func applyingPhotoEffectTransfer() -> CIImage {
        let filter = CIFilter.photoEffectTransfer()
        filter.inputImage = self
        return filter.outputImage!
    }

    func applyingBlendWithAlphaMask(
        backgroundImage: CIImage,
        maskImage: CIImage
    ) -> CIImage {
        let filter = CIFilter.blendWithAlphaMask()
        filter.inputImage = self
        filter.backgroundImage = backgroundImage
        filter.maskImage = maskImage
        return filter.outputImage!
    }

    func applyingBlendWithMask(
        backgroundImage: CIImage,
        maskImage: CIImage
    ) -> CIImage {
        let filter = CIFilter.blendWithMask()
        filter.inputImage = self
        filter.backgroundImage = backgroundImage
        filter.maskImage = maskImage
        return filter.outputImage!
    }

    func applyingBoxBlur(radius: Float) -> CIImage {
        let filter = CIFilter.boxBlur()
        filter.inputImage = self
        filter.radius = radius
        return filter.outputImage!
    }

    func applyingDiscBlur(radius: Float) -> CIImage {
        let filter = CIFilter.discBlur()
        filter.inputImage = self
        filter.radius = radius
        return filter.outputImage!
    }

    func applyingZoomBlur(
        center: CGPoint,
        amount: Float
    ) -> CIImage {
        let filter = CIFilter.zoomBlur()
        filter.inputImage = self
        filter.center = center
        filter.amount = amount
        return filter.outputImage!
    }

    func applyingColorClamp(
        minComponents: CIVector = CIVector(x: 0, y: 0, z: 0, w: 0),
        maxComponents: CIVector = CIVector(x: 1, y: 1, z: 1, w: 1)
    ) -> CIImage {
        let filter = CIFilter.colorClamp()
        filter.inputImage = self
        filter.minComponents = minComponents
        filter.maxComponents = maxComponents
        return filter.outputImage!
    }

    func applyingColorCrossPolynomial(
        redCoefficients: CIVector = CIVector(x: 1, y: 0, z: 0),
        greenCoefficients: CIVector = CIVector(x: 0, y: 1, z: 0),
        blueCoefficients: CIVector = CIVector(x: 0, y: 0, z: 1)
    ) -> CIImage {
        let filter = CIFilter.colorCrossPolynomial()
        filter.inputImage = self
        filter.redCoefficients = redCoefficients
        filter.greenCoefficients = greenCoefficients
        filter.blueCoefficients = blueCoefficients
        return filter.outputImage!
    }

    func applyingColorCube(
        cubeData: Data,
        cubeDimension: Float
    ) -> CIImage {
        let filter = CIFilter.colorCube()
        filter.inputImage = self
        filter.cubeData = cubeData
        filter.cubeDimension = cubeDimension
        return filter.outputImage!
    }

    func applyingColorInvert() -> CIImage {
        let filter = CIFilter.colorInvert()
        filter.inputImage = self
        return filter.outputImage!
    }

    func applyingColorMap(gradientImage: CIImage) -> CIImage {
        let filter = CIFilter.colorMap()
        filter.inputImage = self
        filter.gradientImage = gradientImage
        return filter.outputImage!
    }

    func applyingColorPosterize(levels: Float) -> CIImage {
        let filter = CIFilter.colorPosterize()
        filter.inputImage = self
        filter.levels = levels
        return filter.outputImage!
    }

    func applyingFalseColor(
        color0: CIColor = .black,
        color1: CIColor = .white
    ) -> CIImage {
        let filter = CIFilter.falseColor()
        filter.inputImage = self
        filter.color0 = color0
        filter.color1 = color1
        return filter.outputImage!
    }

    func applyingMaskedVariableBlur(
        mask: CIImage,
        radius: Float
    ) -> CIImage {
        let filter = CIFilter.maskedVariableBlur()
        filter.inputImage = self
        filter.mask = mask
        filter.radius = radius
        return filter.outputImage!
    }

    func applyingSharpenLuminance(sharpness: Float) -> CIImage {
        let filter = CIFilter.sharpenLuminance()
        filter.inputImage = self
        filter.sharpness = sharpness
        return filter.outputImage!
    }

    func applyingColorCurves(_ curves: [Float32], domain: CIVector = CIVector(x: 0, y: 1)) -> CIImage {
        let filter = CIFilter.colorCurves()
        filter.inputImage = self
        filter.curvesDomain = domain
        filter.curvesData = Data(bytes: curves, count: curves.count * MemoryLayout<Float32>.size)
        filter.colorSpace = CGColorSpaceCreateDeviceRGB()
        return filter.outputImage!
    }

    func applyingWhitePointAdjust(color: CIColor) -> CIImage {
        let filter = CIFilter.whitePointAdjust()
        filter.inputImage = self
        filter.color = color
        return filter.outputImage!
    }
}
