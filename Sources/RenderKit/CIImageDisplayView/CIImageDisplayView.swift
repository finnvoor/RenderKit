import CoreImage
import MetalKit
#if canImport(UIKit)
import UIKit

public typealias PlatformView = UIView
#elseif canImport(AppKit)
import AppKit

public typealias PlatformView = NSView
#endif

// MARK: - CIImageDisplayView

/// A view that displays `CIImage` objects.
public class CIImageDisplayView: PlatformView {
    // MARK: Lifecycle

    override public init(frame frameRect: CGRect) {
        device = MTLCreateSystemDefaultDevice()!
        commandQueue = device.makeCommandQueue()!
        context = CIContext(
            mtlCommandQueue: commandQueue,
            options: [
                .name: "RenderKit.CIImageDisplayView",
                .cacheIntermediates: false
            ]
        )
        mtkView = MTKView(frame: .zero, device: device)
        super.init(frame: frameRect)
        setupViews()
    }

    public init(
        device: MTLDevice = MTLCreateSystemDefaultDevice()!,
        commandQueue: MTLCommandQueue? = nil,
        context: CIContext? = nil
    ) {
        self.device = device
        self.commandQueue = commandQueue ?? device.makeCommandQueue()!
        self.context = context ?? CIContext(
            mtlCommandQueue: self.commandQueue,
            options: [
                .name: "RenderKit.CIImageDisplayView",
                .cacheIntermediates: false
            ]
        )
        mtkView = MTKView(frame: .zero, device: device)
        super.init()
        setupViews()
    }

    public required init?(coder: NSCoder) {
        device = MTLCreateSystemDefaultDevice()!
        commandQueue = device.makeCommandQueue()!
        context = CIContext(
            mtlCommandQueue: commandQueue,
            options: [
                .name: "RenderKit.CIImageDisplayView",
                .cacheIntermediates: false
            ]
        )
        mtkView = MTKView(frame: .zero, device: device)
        super.init(coder: coder)
        setupViews()
    }

    // MARK: Public

    /// A value that indicates how the view displays images within its bounds.
    ///
    /// The default value is `scaleAspectFit`.
    public var gravity: CIImage.ContentMode = .scaleAspectFit {
        didSet { mtkView.setNeedsDisplay(bounds) }
    }

    /// Enqueues an image to be displayed.
    public func enqueue(_ image: CIImage) {
        self.image = image
    }

    // MARK: Private

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let context: CIContext
    private let mtkView: MTKView

    private var image: CIImage? {
        didSet { mtkView.setNeedsDisplay(bounds) }
    }

    private func setupViews() {
        #if canImport(UIKit)
        mtkView.isOpaque = false
        #elseif canImport(AppKit)
        mtkView.layer?.isOpaque = false
        #endif
        mtkView.isPaused = true
        mtkView.enableSetNeedsDisplay = true
        mtkView.framebufferOnly = false
        mtkView.delegate = self

        mtkView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mtkView)
        NSLayoutConstraint.activate([
            mtkView.leadingAnchor.constraint(equalTo: leadingAnchor),
            mtkView.trailingAnchor.constraint(equalTo: trailingAnchor),
            mtkView.topAnchor.constraint(equalTo: topAnchor),
            mtkView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

// MARK: MTKViewDelegate

extension CIImageDisplayView: MTKViewDelegate {
    public func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {}

    public func draw(in view: MTKView) {
        guard let image,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let drawable = view.currentDrawable else { return }

        let renderDestination = CIRenderDestination(
            width: Int(view.drawableSize.width),
            height: Int(view.drawableSize.height),
            pixelFormat: view.colorPixelFormat,
            commandBuffer: commandBuffer,
            mtlTextureProvider: { drawable.texture }
        )

        _ = try? context.startTask(
            toRender: image.resized(
                to: CGRect(origin: .zero, size: view.drawableSize),
                contentMode: gravity
            ).composited(over: .clear),
            to: renderDestination
        )

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
