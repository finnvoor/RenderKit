# RenderKit

Utilities for image and video rendering on Apple platforms.

### `CIImageDisplayView`

A view that displays CIImage objects with configurable content mode/gravity.

#### SwiftUI

```swift
struct CIImageDisplayViewDemo: View {
    @State private var image = CIImage(color: .red)
    
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

