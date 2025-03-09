import SwiftUI

#if canImport(UIKit)
/// A view that displays `CIImage` objects.
public struct CIImageDisplayViewRepresentable: UIViewRepresentable {
    // MARK: Lifecycle

    public init(image: Binding<CIImage>, gravity: CIImage.ContentMode = .scaleAspectFit) {
        _image = image
        self.gravity = gravity
    }

    // MARK: Public

    /// The image to display.
    @Binding public var image: CIImage

    /// A value that indicates how the view displays images within its bounds.
    ///
    /// The default value is `scaleAspectFit`.
    public var gravity: CIImage.ContentMode = .scaleAspectFit

    public func makeUIView(context _: Context) -> CIImageDisplayView {
        let view = CIImageDisplayView()
        view.gravity = gravity
        view.enqueue(image)
        return view
    }

    public func updateUIView(_ imageDisplayView: CIImageDisplayView, context _: Context) {
        imageDisplayView.gravity = gravity
        imageDisplayView.enqueue(image)
    }
}

#elseif canImport(AppKit)
public struct CIImageDisplayViewRepresentable: NSViewRepresentable {
    // MARK: Lifecycle

    public init(image: Binding<CIImage>, gravity: CIImage.ContentMode = .scaleAspectFit) {
        _image = image
        self.gravity = gravity
    }

    // MARK: Public

    /// The image to display.
    @Binding public var image: CIImage

    /// A value that indicates how the view displays images within its bounds.
    ///
    /// The default value is `scaleAspectFit`.
    public var gravity: CIImage.ContentMode = .scaleAspectFit

    public func makeNSView(context _: Context) -> CIImageDisplayView {
        let view = CIImageDisplayView()
        view.gravity = gravity
        view.enqueue(image)
        return view
    }

    public func updateNSView(_ imageDisplayView: CIImageDisplayView, context _: Context) {
        imageDisplayView.gravity = gravity
        imageDisplayView.enqueue(image)
    }
}
#endif
