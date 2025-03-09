# RenderKit

Utilities for image and video rendering on Apple platforms.

## `CIImageDisplayView`

A view that displays CIImage objects with configurable content mode/gravity.

#### SwiftUI

```swift
struct CIImageDisplayViewDemo: View {
    @State var image = CIImage(color: .red)
    
    var body: some View {
        CIImageDisplayViewRepresentable(
            image: $image,
            gravity: .scaleAspectFit
        )
    }
}
```

#### UIKit

```swift
let displayView = CIImageDisplayView()
displayView.gravity = .scaleAspectFit
view.addSubview(displayView)

displayView.enqueue(CIImage(color: .red))
```

#### AppKit

```swift
let displayView = CIImageDisplayView()
displayView.gravity = .scaleAspectFit
view.addSubview(displayView)

displayView.enqueue(CIImage(color: .red))
```

## `CompositionDebugView`

A view that displays an `AVComposition` object and optional associated `AVVideoComposition` and `AVAudioMix`.

![](https://github.com/user-attachments/assets/f7ea41ac-936d-48b6-b653-5b387fcb8f7b)

#### SwiftUI

```swift
struct CompositionDebugViewDemo: View {
    let composition: AVComposition = ...
    let videoComposition: AVVideoComposition? = ...
    let audioMix: AVAudioMix? = ...
    
    var body: some View {
        CompositionDebugView(
            composition: composition,
            videoComposition: videoComposition,
            audioMix: audioMix
        )
    }
}
```
