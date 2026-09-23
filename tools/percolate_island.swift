import AppKit
import AVFoundation
import QuartzCore

// Renders Percolate's expanded notch island from the app's own CupScene/CupLayer as a
// seamless looping H.264 video plus a poster frame. The page clips both to the island shape;
// the elapsed time is live HTML, so it's left out here.
// Geometry is a MacBook notch, 179 × 32 pt.

let notchWidth: CGFloat = 179
let height: CGFloat = 32
let wing = (height * CupScene.referenceSize.width / CupScene.referenceSize.height).rounded()
let flare = (height * 0.2).rounded()
let bottomRadius = (height * 0.4).rounded()
let islandWidth = notchWidth + 2 * wing + 2 * flare
let S: CGFloat = 6
let W = Int(islandWidth * S), H = Int(height * S)
let out = URL(fileURLWithPath: CommandLine.arguments[1])

/// IslandShape.path(in:) from IslandView.swift, in y-down points.
func islandPath() -> CGPath {
    let rect = CGRect(x: 0, y: 0, width: islandWidth, height: height)
    let left = rect.minX + flare, right = rect.maxX - flare
    let radius = min(bottomRadius, (right - left) / 2, rect.height - flare)
    let p = CGMutablePath()
    p.move(to: CGPoint(x: rect.minX, y: rect.minY))
    p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    p.addQuadCurve(to: CGPoint(x: right, y: rect.minY + flare), control: CGPoint(x: right, y: rect.minY))
    p.addArc(tangent1End: CGPoint(x: right, y: rect.maxY), tangent2End: CGPoint(x: left, y: rect.maxY), radius: radius)
    p.addArc(tangent1End: CGPoint(x: left, y: rect.maxY), tangent2End: CGPoint(x: left, y: rect.minY), radius: radius)
    p.addLine(to: CGPoint(x: left, y: rect.minY + flare))
    p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: left, y: rect.minY))
    p.closeSubpath()
    return p
}

/// SVG path data for the island, normalised to a 0…1 box for a CSS mask.
func svgPathData() -> String {
    var d = ""
    func f(_ v: CGFloat) -> String { String(format: "%.4f", v) }
    let sx = 1 / islandWidth, sy = 1 / height
    islandPath().applyWithBlock { el in
        let pts = el.pointee.points
        switch el.pointee.type {
        case .moveToPoint: d += "M\(f(pts[0].x * sx)) \(f(pts[0].y * sy)) "
        case .addLineToPoint: d += "L\(f(pts[0].x * sx)) \(f(pts[0].y * sy)) "
        case .addQuadCurveToPoint: d += "Q\(f(pts[0].x * sx)) \(f(pts[0].y * sy)) \(f(pts[1].x * sx)) \(f(pts[1].y * sy)) "
        case .addCurveToPoint: d += "C\(f(pts[0].x * sx)) \(f(pts[0].y * sy)) \(f(pts[1].x * sx)) \(f(pts[1].y * sy)) \(f(pts[2].x * sx)) \(f(pts[2].y * sy)) "
        case .closeSubpath: d += "Z"
        @unknown default: break
        }
    }
    return d
}

@MainActor
func draw(into ctx: CGContext, cup: CupLayer, poseTime: Double, waveTime: Double, breathTime: Double) {
    ctx.saveGState()
    // Opaque black: outside the island is clipped away by the page.
    ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    // y-down, in points
    ctx.translateBy(x: 0, y: CGFloat(H))
    ctx.scaleBy(x: S, y: -S)
    cup.show(CupLayer.frame(for: CupScene.pose(at: poseTime)), waveTime: waveTime, breathTime: breathTime)
    // The context is already y-down, matching the cup root's flipped geometry.
    ctx.translateBy(x: flare, y: 0)
    cup.root.render(in: ctx)
    ctx.restoreGState()
}

func writePNG(_ ctx: CGContext, _ url: URL) {
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
    print("wrote", url.lastPathComponent)
}

MainActor.assumeIsolated {
    let cup = CupLayer()
    cup.fit(to: CGSize(width: wing, height: height), backingScale: S)
    let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
    print("island", islandWidth, "x", height, "pt;", W, "x", H, "px")
    print("clip path (index.html #island-clip):", svgPathData())

    // Poster: the first frame of the loop, cup full and steaming.
    let still = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    draw(into: still, cup: cup, poseTime: CupScene.firstSip, waveTime: 0, breathTime: 0)
    writePNG(still, out.appendingPathComponent("percolate-poster.png"))

    // Video: one full cycle, steam clocks stretched to whole periods so the loop closes.
    let fps = 30.0
    let cycle = CupScene.cycleLength
    let frames = Int((cycle * fps).rounded())
    let waveScale = (cycle / CupLayer.wavePeriod).rounded() * CupLayer.wavePeriod / cycle
    let breathScale = max(1, (cycle / CupLayer.breathPeriod).rounded(.down)) * CupLayer.breathPeriod / cycle
    let videoURL = out.appendingPathComponent("percolate-island.mp4")
    try? FileManager.default.removeItem(at: videoURL)
    let writer = try! AVAssetWriter(outputURL: videoURL, fileType: .mp4)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: W, AVVideoHeightKey: H,
        AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 900_000, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel],
        AVVideoColorPropertiesKey: [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                                    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2],
    ])
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H])
    writer.add(input)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)
    for i in 0..<frames {
        while !input.isReadyForMoreMediaData { RunLoop.current.run(until: Date().addingTimeInterval(0.005)) }
        var pb: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
        CVPixelBufferLockBaseAddress(pb!, [])
        let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb!), width: W, height: H, bitsPerComponent: 8,
                            bytesPerRow: CVPixelBufferGetBytesPerRow(pb!), space: srgb,
                            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
        let t = Double(i) / fps
        draw(into: ctx, cup: cup, poseTime: CupScene.firstSip + t, waveTime: t * waveScale, breathTime: t * breathScale)
        CVPixelBufferUnlockBaseAddress(pb!, [])
        adaptor.append(pb!, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: CMTimeScale(fps)))
    }
    input.markAsFinished()
    let done = DispatchSemaphore(value: 0)
    writer.finishWriting { done.signal() }
    while done.wait(timeout: .now()) == .timedOut { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
    print("wrote", videoURL.lastPathComponent, frames, "frames", writer.status.rawValue, writer.error as Any)
}
