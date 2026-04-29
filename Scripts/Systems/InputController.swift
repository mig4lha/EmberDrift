import CoreGraphics

final class InputController {
    private var touchId: ObjectIdentifier?
    private var anchor: CGPoint = .zero
    private(set) var moveVector: CGPoint = .zero // normalized-ish

    func beginTouch(_ touch: AnyObject, at location: CGPoint) {
        if touchId == nil {
            touchId = ObjectIdentifier(touch)
            anchor = location
            moveVector = .zero
        }
    }

    func moveTouch(_ touch: AnyObject, to location: CGPoint) {
        guard touchId == ObjectIdentifier(touch) else { return }
        let delta = location - anchor
        let maxRadius: CGFloat = 60
        let clamped = delta.length > maxRadius ? delta.normalized() * maxRadius : delta
        moveVector = (clamped * (1 / maxRadius))
    }

    func endTouch(_ touch: AnyObject) {
        guard touchId == ObjectIdentifier(touch) else { return }
        touchId = nil
        moveVector = .zero
    }
}

