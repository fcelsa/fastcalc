import AppKit

public enum WindowPlacement {
    public static let minimumSize = NSSize(width: 420, height: 280)
    public static let margin: CGFloat = 16

    public static func bottomRightFrame(on screen: NSScreen, size: NSSize = minimumSize) -> NSRect {
        let visible = screen.visibleFrame
        let originX = visible.maxX - size.width - margin
        let originY = visible.minY + margin
        return NSRect(origin: NSPoint(x: originX, y: originY), size: size)
    }
}
