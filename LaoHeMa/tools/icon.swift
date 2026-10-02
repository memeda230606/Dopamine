// A small original vector icon; no upstream brand assets are reused.
import AppKit
let destination = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
NSColor(calibratedRed: 0.13, green: 0.35, blue: 0.32, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
let light = NSColor(calibratedRed: 0.84, green: 0.92, blue: 0.83, alpha: 1)
func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: NSColor) {
    color.setFill(); NSBezierPath(ovalIn: NSRect(x: x, y: y, width: w, height: h)).fill()
}
oval(220, 650, 160, 164, light); oval(644, 650, 160, 164, light)
light.setFill()
NSBezierPath(roundedRect: NSRect(x: 240, y: 250, width: 544, height: 495), xRadius: 215, yRadius: 215).fill()
oval(179, 238, 666, 335, light)
let dark = NSColor(calibratedRed: 0.13, green: 0.35, blue: 0.32, alpha: 1)
oval(358, 602, 46, 46, dark); oval(620, 602, 46, 46, dark)
oval(334, 407, 46, 65, dark); oval(644, 407, 46, 65, dark)
dark.setStroke()
let mouth = NSBezierPath(); mouth.lineWidth = 20; mouth.lineCapStyle = .round
mouth.move(to: NSPoint(x: 387, y: 324)); mouth.curve(to: NSPoint(x: 637, y: 324), controlPoint1: NSPoint(x: 470, y: 286), controlPoint2: NSPoint(x: 554, y: 286)); mouth.stroke()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination))
