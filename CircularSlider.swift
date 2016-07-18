//
//  CircularSlider.swift
//  Soundz
//
//  Created by 潘則諺 on 2016/7/17.
//  Copyright © 2016年 Jackal Pan. All rights reserved.
//

import UIKit
import QuartzCore
import Foundation

enum CircularSliderHandleType {
    case SemiTransparentWhiteSmallCircle,
    SemiTransparentWhiteCircle,
    SemiTransparentBlackCircle,
    BigCircle
}
//-------------------- [CircularSliderHandle] --------------------
class CircularSliderHandle: CALayer {
    var highlighted = false
}
//-------------------- [CircularSliderHandle] --------------------
public class CircularTrig {
    
    public class func angleRelativeToNorthFromPoint(fromPoint: CGPoint, toPoint: CGPoint) -> CGFloat {
        var v = CGPointMake(toPoint.x - fromPoint.x, toPoint.y - fromPoint.y)
        let vmag = CGFloat(sqrt(square(Double(v.x)) + square(Double(v.y))))
        v.x /= vmag
        v.y /= vmag
        let cartesianRadians = Double(atan2(v.y, v.x))
        // Need to convert from cartesian style radians to compass style
        var compassRadians = cartesianToCompass(cartesianRadians)
        if (compassRadians < 0) {
            compassRadians += (2 * M_PI)
        }
        assert(compassRadians >= 0 && compassRadians <= 2 * M_PI, "angleRelativeToNorth should be always positive")
        return CGFloat(toDeg(compassRadians))
    }
    
    public class func pointOnRadius(radius: CGFloat, atAngleFromNorth: CGFloat) -> CGPoint {
        //Get the point on the circle for this angle
        var result = CGPoint()
        // Need to adjust from 'compass' style angle to cartesian angle
        let cartesianAngle = CGFloat(compassToCartesian(toRad(Double(atAngleFromNorth))))
        result.y = round(radius * sin(cartesianAngle))
        result.x = round(radius * cos(cartesianAngle))
        
        return result
    }
    
    // MARK: Draw Arcs
    public class func drawFilledCircleInContext(ctx: CGContextRef, center: CGPoint, radius: CGFloat) -> CGRect {
        let frame = CGRectMake(center.x - radius, center.y - radius, 2 * radius, 2 * radius)
        CGContextFillEllipseInRect(ctx, frame)
        return frame
    }
    
    public class func drawUnfilledCircleInContext(ctx: CGContextRef, center: CGPoint, radius: CGFloat, lineWidth: CGFloat, maximumAngle: CGFloat, lineCap: CGLineCap) {
        // by using maximumAngle an incomplete circle can be drawn
        drawUnfilledArcInContext(ctx, center: center, radius: radius, lineWidth: lineWidth, fromAngleFromNorth: 0, toAngleFromNorth: maximumAngle, lineCap: lineCap)
    }
    
    public class func drawUnfilledArcInContext(ctx: CGContextRef, center: CGPoint, radius: CGFloat, lineWidth: CGFloat, fromAngleFromNorth: CGFloat, toAngleFromNorth: CGFloat, lineCap: CGLineCap) {
        let cartesianFromAngle = compassToCartesian(toRad(Double(fromAngleFromNorth)))
        let cartesianToAngle = compassToCartesian(toRad(Double(toAngleFromNorth)))
        
        CGContextAddArc(ctx,
            center.x,   // arc start point x
            center.y,   // arc start point y
            radius,     // arc radius from center
            CGFloat(cartesianFromAngle), CGFloat(cartesianToAngle),
            0) // iOS flips the y coordinate so anti-clockwise (specified here by 0) becomes clockwise (desired)!
        
        CGContextSetLineWidth(ctx, lineWidth)
        CGContextSetLineCap(ctx, lineCap)
        CGContextDrawPath(ctx, CGPathDrawingMode.Stroke)
    }
    
    public class func drawUnfilledGradientArcInContext(ctx: CGContextRef, center: CGPoint, radius: CGFloat, lineWidth: CGFloat, maximumAngle: CGFloat, colors: [UIColor], lineCap: CGLineCap) {
        // ensure two colors exist to create a gradient between
        guard colors.count == 2 else {
            return
        }
        
        let cartesianFromAngle = compassToCartesian(toRad(Double(0)))
        let cartesianToAngle = compassToCartesian(toRad(Double(maximumAngle)))
        
        CGContextSaveGState(ctx)
        
        let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: CGFloat(cartesianFromAngle), endAngle: CGFloat(cartesianToAngle), clockwise: true)
        let containerPath = CGPathCreateCopyByStrokingPath(path.CGPath, nil, CGFloat(lineWidth), lineCap, CGLineJoin.Round, lineWidth)
        CGContextAddPath(ctx, containerPath)
        CGContextClip(ctx)
        
        let baseSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradientCreateWithColors(baseSpace, [colors[1].CGColor, colors[0].CGColor], nil)
        let startPoint = CGPointMake(center.x - radius, center.y + radius)
        let endPoint = CGPointMake(center.x + radius, center.y - radius)
        CGContextDrawLinearGradient(ctx, gradient, startPoint, endPoint, .DrawsBeforeStartLocation)
        
        CGContextRestoreGState(ctx)
    }
    
    public class func degreesForArcLength(arcLength: CGFloat, onCircleWithRadius radius: CGFloat, withMaximumAngle degrees: CGFloat) -> CGFloat {
        let totalCircumference = CGFloat(2 * M_PI) * radius
        
        let arcRatioToCircumference = arcLength / totalCircumference
        
        return degrees * arcRatioToCircumference // If arcLength is exactly half circumference, that is exactly half a circle in degrees
    }
    
    // MARK: Calculate radii of arcs with line widths
    /*
     *  For an unfilled arc.
     *
     *  Radius of outer arc (center to outside edge)  |          ---------
     *      = radius + 0.5 * lineWidth                |      +++++++++++++++
     *                                                |    /++/++++ --- ++++\++\
     *  Radius of inner arc (center to inside edge)   |   /++/++/         \++\++\
     *      = radius - (0.5 * lineWidth)              |  |++|++|     .     |++|++|
     *                                         outer edge^  ^-radius-^     ^inner edge
     *
     */
    public class func outerRadiuOfUnfilledArcWithRadius(radius: CGFloat, lineWidth: CGFloat) -> CGFloat {
        return radius + 0.5 * lineWidth
    }
    
    public class func innerRadiusOfUnfilledArcWithRadius(radius :CGFloat, lineWidth: CGFloat) -> CGFloat {
        return radius - 0.5 * lineWidth
    }
}

// MARK: - Utility Math
extension CircularTrig {
    
    /**
     *  Macro for converting radian degrees from 'compass style' reference (0 radians is along Y axis (ie North on a compass))
     *   to cartesian reference (0 radians is along X axis).
     *
     *  @param rad Radian degrees to convert from 'Compass' reference
     *
     *  @return Radian Degrees in Cartesian reference
     */
    private class func toRad(degrees: Double) -> Double {
        return ((M_PI * degrees) / 180.0)
    }
    
    private class func toDeg(radians: Double) -> Double {
        return ((180.0 * radians) / M_PI)
    }
    
    private class func square(value: Double) -> Double {
        return value * value
    }
    
    /**
     *  Macro for converting radian degrees from cartesian reference (0 radians is along X axis)
     *   to 'compass style' reference (0 radians is along Y axis (ie North on a compass)).
     *
     *  @param rad Radian degrees to convert from Cartesian reference
     *
     *  @return Radian Degrees in 'Compass' reference
     */
    private class func cartesianToCompass(radians: Double) -> Double {
        return radians + (M_PI/2)
    }
    
    private class func compassToCartesian(radians: Double) -> Double {
        return radians - (M_PI/2)
    }
}
//-------------------- [CircularSlider] --------------------
class CircularSlider: UIControl {
    
    // MARK: Values
    // Value at North/midnight (start)
    var minimumValue: Float = 0.0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // Value at North/midnight (end)
    var maximumValue: Float = 100.0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // value for end of arc. This allows for incomplete circles to be created
    var maximumAngle: CGFloat = 360.0 {
        didSet {
            if maximumAngle > 360.0 {
                print("Warning: Maximum angle should be 360 or less.")
                maximumAngle = 360.0
            }
            setNeedsDisplay()
        }
    }
    
    // Current value between North/midnight (start) and North/midnight (end) - clockwise direction
    var currentValue: Float {
        set {
            assert(newValue <= maximumValue && newValue >= minimumValue, "current value \(newValue) must be between minimumValue \(minimumValue) and maximumValue \(maximumValue)")
            // Update the angleFromNorth to match this newly set value
            angleFromNorth = Int((newValue * Float(maximumAngle)) / (maximumValue - minimumValue))
            moveHandle(CGFloat(angleFromNorth))
            sendActionsForControlEvents(UIControlEvents.ValueChanged)
        } get {
            return (Float(angleFromNorth) * (maximumValue - minimumValue)) / Float(maximumAngle)
        }
    }
    
    // MARK: Handle
    let circularSliderHandle = CircularSliderHandle()
    
    /**
     *  Note: If this property is not set, filledColor will be used.
     *        If handleType is semiTransparent*, specified color will override this property.
     *
     *  Color of the handle
     */
    var handleColor: UIColor? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // Type of the handle to display to represent draggable current value
    var handleType: CircularSliderHandleType = .SemiTransparentWhiteSmallCircle {
        didSet {
            setNeedsUpdateConstraints()
            setNeedsDisplay()
        }
    }
    
    // MARK: Labels
    // BOOL indicating whether values snap to nearest label
    var snapToLabels: Bool = false
    
    /**
     *  Note: The LAST label will appear at North/midnight
     *        The FIRST label will appear at the first interval after North/midnight
     *
     *  NSArray of strings used to render labels at regular intervals within the circle
     */
    var innerMarkingLabels: [String]? {
        didSet {
            setNeedsUpdateConstraints()
            setNeedsDisplay()
        }
    }
    
    
    // MARK: Visual Customisation
    // property Width of the line to draw for slider
    var lineWidth: Int = 5 {
        didSet {
            setNeedsUpdateConstraints() // This could affect intrinsic content size
            invalidateIntrinsicContentSize() // Need to update intrinsice content size
            setNeedsDisplay() // Need to redraw with new line width
        }
    }
    
    // Color of filled portion of line (from North/midnight start to currentValue)
    var filledColor: UIColor = .redColor() {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // Color of unfilled portion of line (from currentValue to North/midnight end)
    var unfilledColor: UIColor = .blackColor() {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // Font of the inner marking labels within the circle
    var labelFont: UIFont = .systemFontOfSize(10.0) {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // Color of the inner marking labels within the circle
    var labelColor: UIColor = .redColor() {
        didSet {
            setNeedsDisplay()
        }
    }
    
    /**
     *  Note: A negative value will move the label closer to the center. A positive value will move the label closer to the circumference
     *  Value with which to displace all labels along radial line from center to slider circumference.
     */
    var labelDisplacement: CGFloat = 0
    
    // type of LineCap to use for the unfilled arc
    // NOTE: user CGLineCap.Butt for full circles
    var unfilledArcLineCap: CGLineCap = .Butt
    
    // type of CGLineCap to use for the arc that is filled in as the handle moves
    var filledArcLineCap: CGLineCap = .Butt
    
    // MARK: Computed Public Properties
    var computedRadius: CGFloat {
        if (radius == -1.0) {
            // Slider is being used in frames - calculate the max radius based on the frame
            //  (constrained by smallest dimension so it fits within view)
            let minimumDimension = min(bounds.size.height, bounds.size.width)
            let halfLineWidth = ceilf(Float(lineWidth) / 2.0)
            let halfHandleWidth = ceilf(Float(handleWidth) / 2.0)
            return minimumDimension * 0.5 - CGFloat(max(halfHandleWidth, halfLineWidth))
        }
        return radius
    }
    
    var centerPoint: CGPoint {
        return CGPointMake(bounds.size.width * 0.5, bounds.size.height * 0.5)
    }
    
    var angleFromNorth: Int = 0 {
        didSet {
            assert(angleFromNorth >= 0, "angleFromNorth \(angleFromNorth) must be greater than 0")
        }
    }
    
    var handleWidth: CGFloat {
        switch handleType {
        case .SemiTransparentWhiteSmallCircle:
            return CGFloat(lineWidth / 2)
        case .SemiTransparentWhiteCircle, .SemiTransparentBlackCircle:
            return CGFloat(lineWidth)
        case .BigCircle:
            return CGFloat(lineWidth + 5) // 5 points bigger than standard handles
        }
    }
    
    // MARK: Private Variables
    private var radius: CGFloat = -1.0 {
        didSet {
            setNeedsUpdateConstraints()
            setNeedsDisplay()
        }
    }
    
    private var computedHandleColor: UIColor? {
        var newHandleColor = handleColor
        
        switch (handleType) {
        case .SemiTransparentWhiteSmallCircle, .SemiTransparentWhiteCircle:
            newHandleColor = UIColor(white: 1.0, alpha: 0.7)
        case .SemiTransparentBlackCircle:
            newHandleColor = UIColor(white: 0.0, alpha: 0.7)
        case .BigCircle:
            newHandleColor = filledColor
        }
        
        return newHandleColor
    }
    
    private var innerLabelRadialDistanceFromCircumference: CGFloat {
        // Labels should be moved far enough to clear the line itself plus a fixed offset (relative to radius).
        var distanceToMoveInwards = 0.1 * -(radius) - 0.5 * CGFloat(lineWidth)
        distanceToMoveInwards -= 0.5 * labelFont.pointSize // Also account for variable font size.
        return distanceToMoveInwards
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clearColor()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        backgroundColor = .clearColor()
    }
    
    // TODO: initializer for autolayout
    /**
     *  Initialise the class with a desired radius
     *  This initialiser should be used for autolayout - use initWithFrame otherwise
     *  Note: Intrinsic content size will be based on this parameter, lineWidth and handleType
     *
     *  radiusToSet Desired radius of circular slider
     */
    //  convenience init(radiusToSet: CGFloat) {
    //
    //  }
    
    // MARK: - Function Overrides
    override func intrinsicContentSize() -> CGSize {
        // Total width is: diameter + (2 * MAX(halfLineWidth, halfHandleWidth))
        let diameter = radius * 2
        let halfLineWidth = ceilf(Float(lineWidth) / 2.0)
        let halfHandleWidth = ceilf(Float(handleWidth) / 2.0)
        
        let widthWithHandle = diameter + CGFloat(2 *  max(halfHandleWidth, halfLineWidth))
        
        return CGSizeMake(widthWithHandle, widthWithHandle)
    }
    
    override func drawRect(rect: CGRect) {
        super.drawRect(rect)
        let ctx = UIGraphicsGetCurrentContext()
        
        // Draw the circular lines that slider handle moves along
        drawLine(ctx!)
        
        // Draw the draggable 'handle'
        let handleCenter = pointOnCircleAtAngleFromNorth(angleFromNorth)
        circularSliderHandle.frame = drawHandle(ctx!, atPoint: handleCenter)
        
        // Draw inner labels
        drawInnerLabels(ctx!, rect: rect)
    }
    
    override func pointInside(point: CGPoint, withEvent event: UIEvent?) -> Bool {
        guard event != nil else { return false }
        
        if pointInsideHandle(point, withEvent: event!) {
            return true
        } else {
            return pointInsideCircle(point, withEvent: event!)
        }
    }
    
    private func pointInsideCircle(point: CGPoint, withEvent event: UIEvent) -> Bool {
        let p1 = centerPoint
        let p2 = point
        let xDist = p2.x - p1.x
        let yDist = p2.y - p1.y
        let distance = sqrt((xDist * xDist) + (yDist * yDist))
        return distance < computedRadius + CGFloat(lineWidth) * 0.5
    }
    
    private func pointInsideHandle(point: CGPoint, withEvent event: UIEvent) -> Bool {
        let handleCenter = pointOnCircleAtAngleFromNorth(angleFromNorth)
        // Adhere to apple's design guidelines - avoid making touch targets smaller than 44 points
        let handleRadius = max(handleWidth, 44.0) * 0.5
        
        // Treat handle as a box around it's center
        let pointInsideHorzontalHandleBounds = (point.x >= handleCenter.x - handleRadius && point.x <= handleCenter.x + handleRadius)
        let pointInsideVerticalHandleBounds  = (point.y >= handleCenter.y - handleRadius && point.y <= handleCenter.y + handleRadius)
        return pointInsideHorzontalHandleBounds && pointInsideVerticalHandleBounds
    }
    
    // MARK: - Drawing methods
    func drawLine(ctx: CGContextRef) {
        unfilledColor.set()
        // Draw an unfilled circle (this shows what can be filled)
        CircularTrig.drawUnfilledCircleInContext(ctx, center: centerPoint, radius: computedRadius, lineWidth: CGFloat(lineWidth), maximumAngle: maximumAngle, lineCap: unfilledArcLineCap)
        
        filledColor.set()
        // Draw an unfilled arc up to the currently filled point
        CircularTrig.drawUnfilledArcInContext(ctx, center: centerPoint, radius: computedRadius, lineWidth: CGFloat(lineWidth), fromAngleFromNorth: 0, toAngleFromNorth: CGFloat(angleFromNorth), lineCap: filledArcLineCap)
    }
    
    func drawHandle(ctx: CGContextRef, atPoint handleCenter: CGPoint) -> CGRect {
        CGContextSaveGState(ctx)
        var frame: CGRect!
        
        // Ensure that handle is drawn in the correct color
        handleColor = computedHandleColor
        handleColor!.set()
        
        frame = CircularTrig.drawFilledCircleInContext(ctx, center: handleCenter, radius: 0.5 * handleWidth)
        
        CGContextSaveGState(ctx)
        return frame
    }
    
    func drawInnerLabels(ctx: CGContextRef, rect: CGRect) {
        if let labels = innerMarkingLabels where labels.count > 0 {
            let attributes = [NSFontAttributeName: labelFont, NSForegroundColorAttributeName: labelColor]
            
            // Enumerate through labels clockwise
            for (var i = 0; i < labels.count; i++) {
                let label = labels[i] as NSString
                let labelFrame = contextCoordinatesForLabelAtIndex(i)
                
                CGContextSaveGState(ctx)
                
                // invert transformation used on arc
                CGContextConcatCTM(ctx, CGAffineTransformMakeTranslation(labelFrame.origin.x + (labelFrame.width / 2), labelFrame.origin.y + (labelFrame.height / 2)))
                CGContextConcatCTM(ctx, CGAffineTransformInvert(getRotationalTransform()))
                CGContextConcatCTM(ctx, CGAffineTransformMakeTranslation(-(labelFrame.origin.x + (labelFrame.width / 2)), -(labelFrame.origin.y + (labelFrame.height / 2))))
                
                // draw label
                label.drawInRect(labelFrame, withAttributes: attributes)
                
                CGContextRestoreGState(ctx)
            }
        }
    }
    
    func contextCoordinatesForLabelAtIndex(index: Int) -> CGRect {
        let label = innerMarkingLabels![index]
        var percentageAlongCircle: CGFloat!
        
        // Determine how many degrees around the full circle this label should go
        if maximumAngle == 360.0 {
            percentageAlongCircle = ((100.0 / CGFloat(innerMarkingLabels!.count)) * CGFloat(index + 1)) / 100.0
        } else {
            percentageAlongCircle = ((100.0 / CGFloat(innerMarkingLabels!.count - 1)) * CGFloat(index)) / 100.0
        }
        
        let degreesFromNorthForLabel = percentageAlongCircle * maximumAngle
        let pointOnCircle = pointOnCircleAtAngleFromNorth(Int(degreesFromNorthForLabel))
        
        let labelSize = sizeOfString(label, withFont: labelFont)
        let offsetFromCircle = offsetFromCircleForLabelAtIndex(index, withSize: labelSize)
        
        return CGRectMake(pointOnCircle.x + offsetFromCircle.x, pointOnCircle.y + offsetFromCircle.y, labelSize.width, labelSize.height)
    }
    
    func offsetFromCircleForLabelAtIndex(index: Int, withSize labelSize: CGSize) -> CGPoint {
        // Determine how many degrees around the full circle this label should go
        let percentageAlongCircle = ((100.0 / CGFloat(innerMarkingLabels!.count - 1)) * CGFloat(index)) / 100.0
        let degreesFromNorthForLabel = percentageAlongCircle * maximumAngle
        
        let radialDistance = innerLabelRadialDistanceFromCircumference + labelDisplacement
        let inwardOffset = CircularTrig.pointOnRadius(radialDistance, atAngleFromNorth: CGFloat(degreesFromNorthForLabel))
        
        return CGPointMake(-labelSize.width * 0.5 + inwardOffset.x, -labelSize.height * 0.5 + inwardOffset.y)
    }
    
    // MARK: - UIControl Functions
    override func continueTrackingWithTouch(touch: UITouch, withEvent event: UIEvent?) -> Bool {
        let lastPoint = touch.locationInView(self)
        let lastAngle = floor(CircularTrig.angleRelativeToNorthFromPoint(centerPoint, toPoint: lastPoint))
        
        moveHandle(lastAngle)
        sendActionsForControlEvents(UIControlEvents.ValueChanged)
        
        return true
    }
    
    private func moveHandle(newAngleFromNorth: CGFloat) {
        
        // prevent slider from moving past maximumAngle
        if newAngleFromNorth > maximumAngle {
            if angleFromNorth < Int(maximumAngle / 2) {
                angleFromNorth = 0
                setNeedsDisplay()
            } else if angleFromNorth > Int(maximumAngle / 2) {
                angleFromNorth = Int(maximumAngle)
                setNeedsDisplay()
            }
        } else {
            angleFromNorth = Int(newAngleFromNorth)
        }
        setNeedsDisplay()
    }
    
    // MARK: - Helper Functions
    func pointOnCircleAtAngleFromNorth(angleFromNorth: Int) -> CGPoint {
        let offset = CircularTrig.pointOnRadius(computedRadius, atAngleFromNorth: CGFloat(angleFromNorth))
        return CGPointMake(centerPoint.x + offset.x, centerPoint.y + offset.y)
    }
    
    func sizeOfString(string: String, withFont font: UIFont) -> CGSize {
        let attributes = [NSFontAttributeName: font]
        return NSAttributedString(string: string, attributes: attributes).size()
    }
    
    func getRotationalTransform() -> CGAffineTransform {
        if maximumAngle == 360 {
            // do not perform a rotation if using a full circle slider
            let transform = CGAffineTransformRotate(CGAffineTransformIdentity, CGFloat(0))
            return transform
        } else {
            // rotate slider view so "north" is at the start
            let radians = Double(-(maximumAngle / 2)) / 180.0 * M_PI
            let transform = CGAffineTransformRotate(CGAffineTransformIdentity, CGFloat(radians))
            return transform
        }
    }
}
