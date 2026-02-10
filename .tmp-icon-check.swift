import AppKit
import Foundation

let url = URL(fileURLWithPath: "/Users/rick.hopkins/Source/MelodicDevelopment/move-now/Sources/MoveNow/Resources/MoveNowIcon.png")
guard let image = NSImage(contentsOf: url) else { fatalError("load failed") }
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff) else { fatalError("rep failed") }

func sample(_ x: Int, _ y: Int) {
    if let c = rep.colorAt(x: x, y: y) {
        print("(\(x),\(y)) a=\(String(format: \"%.3f\", c.alphaComponent)) r=\(String(format: \"%.3f\", c.redComponent)) g=\(String(format: \"%.3f\", c.greenComponent)) b=\(String(format: \"%.3f\", c.blueComponent))")
    }
}
print("size", rep.pixelsWide, rep.pixelsHigh)
sample(0,0)
sample(rep.pixelsWide/2, rep.pixelsHigh/2)
sample(100,100)
