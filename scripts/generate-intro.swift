import AVFoundation
import CoreGraphics
import CoreText
import CoreVideo
import Foundation
import ImageIO

let width = 1920
let height = 1080
let framesPerSecond: Int32 = 30
let duration: Double = 4.8
let outputURL = URL(fileURLWithPath: "assets/brand/3h33-intro.mp4")
let posterURL = URL(fileURLWithPath: "assets/brand/3h33-intro-poster.jpg")
let logoURL = URL(fileURLWithPath: "assets/brand/3h33-logo.png")

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
  guard condition() else {
    throw NSError(domain: "3H33Intro", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
  }
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
  CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [red, green, blue, alpha])!
}

func smoothstep(_ value: CGFloat) -> CGFloat {
  let t = min(1, max(0, value))
  return t * t * (3 - 2 * t)
}

func text(_ string: String, size: CGFloat, tracking: CGFloat, color: CGColor, centeredAt x: CGFloat, y: CGFloat, in context: CGContext) {
  let font = CTFontCreateWithName("HelveticaNeue" as CFString, size, nil)
  let attributes: [NSAttributedString.Key: Any] = [
    NSAttributedString.Key(kCTFontAttributeName as String): font,
    NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
    NSAttributedString.Key(kCTKernAttributeName as String): tracking
  ]
  let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
  let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
  context.textPosition = CGPoint(x: x - lineWidth / 2, y: y)
  CTLineDraw(line, context)
}

func loadWhiteLogo() throws -> CGImage {
  guard let source = CGImageSourceCreateWithURL(logoURL as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    throw NSError(domain: "3H33Intro", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not read assets/brand/3h33-logo.png"])
  }

  let rowBytes = image.width * 4
  guard let context = CGContext(
    data: nil,
    width: image.width,
    height: image.height,
    bitsPerComponent: 8,
    bytesPerRow: rowBytes,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
  ) else {
    throw NSError(domain: "3H33Intro", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not process the logo image"])
  }
  context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

  let pixels = context.data!.assumingMemoryBound(to: UInt8.self)
  var minX = image.width
  var minY = image.height
  var maxX = 0
  var maxY = 0
  for y in 0..<image.height {
    for x in 0..<image.width where pixels[y * rowBytes + x * 4 + 3] > 12 {
      minX = min(minX, x)
      minY = min(minY, y)
      maxX = max(maxX, x)
      maxY = max(maxY, y)
    }
  }
  try require(maxX > minX && maxY > minY, "The supplied logo has no visible pixels.")

  let padding = Int(Double(max(maxX - minX, maxY - minY)) * 0.035)
  let left = max(0, minX - padding)
  let bottom = max(0, minY - padding)
  let right = min(image.width, maxX + padding + 1)
  let top = min(image.height, maxY + padding + 1)
  let crop = CGRect(x: left, y: bottom, width: right - left, height: top - bottom)
  guard let croppedImage = image.cropping(to: crop),
        let whiteContext = CGContext(
          data: nil,
          width: croppedImage.width,
          height: croppedImage.height,
          bitsPerComponent: 8,
          bytesPerRow: croppedImage.width * 4,
          space: CGColorSpace(name: CGColorSpace.sRGB)!,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
    throw NSError(domain: "3H33Intro", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not crop the logo"])
  }
  let logoRect = CGRect(x: 0, y: 0, width: croppedImage.width, height: croppedImage.height)
  whiteContext.draw(croppedImage, in: logoRect)
  whiteContext.setBlendMode(.sourceIn)
  whiteContext.setFillColor(color(1, 1, 1))
  whiteContext.fill(logoRect)

  guard let whiteLogo = whiteContext.makeImage() else {
    throw NSError(domain: "3H33Intro", code: 5, userInfo: [NSLocalizedDescriptionKey: "Could not create the animated logo"])
  }
  print("Using trimmed \(whiteLogo.width) × \(whiteLogo.height) logo.")
  return whiteLogo
}

func drawFrame(_ frame: Int, logo: CGImage, context: CGContext) {
  let time = CGFloat(frame) / CGFloat(framesPerSecond)
  let bounds = CGRect(x: 0, y: 0, width: width, height: height)
  let center = CGPoint(x: CGFloat(width) / 2, y: CGFloat(height) / 2 + 10)
  context.clear(bounds)
  context.setFillColor(color(0.018, 0.021, 0.016))
  context.fill(bounds)
  if let gradient = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    colors: [color(0.12, 0.17, 0.075, 0.8), color(0.018, 0.021, 0.016, 0)].map { $0 } as CFArray,
    locations: [0, 1]
  ) {
    context.drawRadialGradient(gradient, startCenter: center, startRadius: 5, endCenter: center, endRadius: 1020, options: .drawsAfterEndLocation)
  }

  let intro = smoothstep((time - 0.12) / 0.8)
  let outro = 1 - smoothstep((time - 4.18) / 0.62)
  let energy = intro * outro

  context.saveGState()
  context.setLineWidth(1)
  for index in 0..<6 {
    let phase = min(1, max(0, time / 4.8))
    let radius = CGFloat(138 + index * 96) + phase * CGFloat(30 + index * 13)
    let alpha = max(0, (0.2 - CGFloat(index) * 0.018) * energy)
    context.setStrokeColor(CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [0.78, 0.96, 0.42, alpha])!)
    context.strokeEllipse(in: CGRect(x: center.x - radius * 1.42, y: center.y - radius * 0.56, width: radius * 2.84, height: radius * 1.12))
  }

  context.setLineWidth(1)
  for index in 0..<30 {
    let x = CGFloat(index) * CGFloat(width) / 29
    let distance = abs(x - center.x) / center.x
    let alpha = (0.025 + distance * 0.04) * energy
    context.setStrokeColor(color(0.74, 0.81, 0.60, alpha))
    context.move(to: CGPoint(x: x, y: 0))
    context.addLine(to: CGPoint(x: x, y: CGFloat(height)))
    context.strokePath()
  }
  for y in stride(from: 0, through: height, by: 64) {
    context.setStrokeColor(color(0.74, 0.81, 0.60, 0.025 * energy))
    context.move(to: CGPoint(x: 0, y: CGFloat(y)))
    context.addLine(to: CGPoint(x: CGFloat(width), y: CGFloat(y)))
    context.strokePath()
  }
  context.restoreGState()

  for index in 0..<56 {
    let seed = CGFloat(index)
    let orbit = seed * 2.399 + time * (0.22 + seed.truncatingRemainder(dividingBy: 5) * 0.025)
    let radius = CGFloat(275 + (index * 137) % 620)
    let x = center.x + cos(orbit) * radius * 1.28
    let y = center.y + sin(orbit) * radius * 0.58
    let alpha = (0.15 + (seed.truncatingRemainder(dividingBy: 4) * 0.08)) * energy
    context.setFillColor(color(0.78, 0.96, 0.42, alpha))
    context.fillEllipse(in: CGRect(x: x, y: y, width: 1 + CGFloat(index % 3), height: 1 + CGFloat(index % 3)))
  }

  let logoSize = min(CGFloat(610), CGFloat(logo.width) * 740 / CGFloat(logo.height))
  let logoHeight = logoSize * CGFloat(logo.height) / CGFloat(logo.width)
  let logoRect = CGRect(x: center.x - logoSize / 2, y: center.y - logoHeight / 2, width: logoSize, height: logoHeight)
  let reveal = smoothstep((time - 0.78) / 1.35)
  let visibleWidth = logoRect.width * reveal

  if reveal > 0 {
    context.saveGState()
    context.clip(to: CGRect(x: logoRect.minX, y: logoRect.minY - 2, width: visibleWidth + 2, height: logoRect.height + 4))
    context.setShadow(offset: .zero, blur: 26, color: color(0.78, 0.96, 0.42, 0.34 * energy))
    context.draw(logo, in: logoRect)
    context.restoreGState()
  }

  let beamX = logoRect.minX + visibleWidth
  if reveal < 1 {
    context.saveGState()
    context.setFillColor(color(0.78, 0.96, 0.42, 0.78 * energy))
    context.fill(CGRect(x: beamX - 1, y: logoRect.minY - 22, width: 2, height: logoRect.height + 44))
    context.setShadow(offset: .zero, blur: 28, color: color(0.78, 0.96, 0.42, 0.92 * energy))
    context.fill(CGRect(x: beamX - 2, y: logoRect.minY - 28, width: 4, height: logoRect.height + 56))
    context.restoreGState()
  }

  let sweep = (time / 2.4).truncatingRemainder(dividingBy: 1)
  let scanY = CGFloat(height) * (0.24 + sweep * 0.52)
  context.saveGState()
  context.setFillColor(color(0.78, 0.96, 0.42, 0.095 * energy))
  context.fill(CGRect(x: 0, y: scanY, width: CGFloat(width), height: 1))
  if frame % 37 < 3 {
    let glitchY = center.y - CGFloat((frame * 19) % 360) + 180
    context.setFillColor(color(0.78, 0.96, 0.42, 0.2 * energy))
    context.fill(CGRect(x: CGFloat(width) * 0.2, y: glitchY, width: CGFloat(width) * 0.6, height: 1))
  }
  context.restoreGState()

  let frameColor = color(0.78, 0.96, 0.42, 0.46 * energy)
  context.setStrokeColor(frameColor)
  context.setLineWidth(1)
  for (x, direction) in [(CGFloat(76), CGFloat(1)), (CGFloat(width - 76), CGFloat(-1))] {
    for y in [CGFloat(64), CGFloat(height - 64)] {
      context.move(to: CGPoint(x: x, y: y))
      context.addLine(to: CGPoint(x: x + 26 * direction, y: y))
      context.move(to: CGPoint(x: x, y: y))
      context.addLine(to: CGPoint(x: x, y: y + (y < center.y ? 26 : -26)))
    }
  }
  context.strokePath()

  let textAlpha = min(1, max(0, (time - 1.8) * 1.4)) * outro
  text("3H33 AGENCY   /   ANGERS", size: 16, tracking: 4, color: color(0.83, 0.91, 0.73, 0.58 * textAlpha), centeredAt: center.x, y: CGFloat(height - 82), in: context)
  text("MANAGEMENT ARTISTIQUE   ·   BOOKING   ·   CULTURE NOCTURNE", size: 12, tracking: 2.1, color: color(0.83, 0.88, 0.75, 0.54 * textAlpha), centeredAt: center.x, y: 66, in: context)
  text("03:33", size: 11, tracking: 2, color: color(0.78, 0.96, 0.42, 0.65 * textAlpha), centeredAt: 110, y: CGFloat(height - 81), in: context)
  text("47°28′N  0°34′W", size: 10, tracking: 1.4, color: color(0.83, 0.88, 0.75, 0.48 * textAlpha), centeredAt: CGFloat(width - 132), y: 66, in: context)

  let fade = time > 4.45 ? max(0, 1 - (time - 4.45) / 0.35) : 1
  if fade < 1 {
    context.setBlendMode(.copy)
    context.setFillColor(color(0.018, 0.021, 0.016, 1 - fade))
    context.fill(bounds)
  }
}

func writePoster(_ image: CGImage) throws {
  guard let destination = CGImageDestinationCreateWithURL(posterURL as CFURL, "public.jpeg" as CFString, 1, nil) else {
    throw NSError(domain: "3H33Intro", code: 6, userInfo: [NSLocalizedDescriptionKey: "Could not create the video poster"])
  }
  CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.88] as CFDictionary)
  try require(CGImageDestinationFinalize(destination), "Could not save the video poster.")
}

do {
  let logo = try loadWhiteLogo()
  for url in [outputURL, posterURL] where FileManager.default.fileExists(atPath: url.path) {
    try FileManager.default.removeItem(at: url)
  }
  let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
  let settings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width,
    AVVideoHeightKey: height,
    AVVideoCompressionPropertiesKey: [
      AVVideoAverageBitRateKey: 5_500_000,
      AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
    ]
  ]
  let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
  input.expectsMediaDataInRealTime = false
  let pixelAttributes: [String: Any] = [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
    kCVPixelBufferWidthKey as String: width,
    kCVPixelBufferHeightKey as String: height,
    kCVPixelBufferCGImageCompatibilityKey as String: true,
    kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
  ]
  let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: pixelAttributes)
  try require(writer.canAdd(input), "Could not configure the H.264 video encoder.")
  writer.add(input)
  try require(writer.startWriting(), "Could not start the H.264 video encoder.")
  writer.startSession(atSourceTime: .zero)

  let frameCount = Int(duration * Double(framesPerSecond))
  for frame in 0..<frameCount {
    while !input.isReadyForMoreMediaData {
      Thread.sleep(forTimeInterval: 0.002)
    }
    guard let pool = adaptor.pixelBufferPool else {
      throw NSError(domain: "3H33Intro", code: 7, userInfo: [NSLocalizedDescriptionKey: "The video encoder did not provide a frame buffer"])
    }
    var optionalBuffer: CVPixelBuffer?
    let result = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &optionalBuffer)
    try require(result == kCVReturnSuccess, "Could not allocate video frame \(frame).")
    let buffer = optionalBuffer!
    CVPixelBufferLockBaseAddress(buffer, [])
    guard let context = CGContext(
      data: CVPixelBufferGetBaseAddress(buffer),
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
      space: CGColorSpace(name: CGColorSpace.sRGB)!,
      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
      CVPixelBufferUnlockBaseAddress(buffer, [])
      throw NSError(domain: "3H33Intro", code: 8, userInfo: [NSLocalizedDescriptionKey: "Could not draw video frame \(frame)."])
    }
    drawFrame(frame, logo: logo, context: context)
    let poster = frame == Int(Double(frameCount) * 0.7) ? context.makeImage() : nil
    CVPixelBufferUnlockBaseAddress(buffer, [])

    let presentationTime = CMTime(value: Int64(frame), timescale: framesPerSecond)
    try require(adaptor.append(buffer, withPresentationTime: presentationTime), "Could not encode video frame \(frame).")
    if let poster { try writePoster(poster) }
  }

  input.markAsFinished()
  let finished = DispatchSemaphore(value: 0)
  writer.finishWriting { finished.signal() }
  finished.wait()
  try require(writer.status == .completed, writer.error?.localizedDescription ?? "Could not finish the intro video.")
  print("Created \(outputURL.path) (\(duration)s, \(width)×\(height), silent H.264).")
  print("Created \(posterURL.path).")
} catch {
  fputs("Intro generation failed: \(error.localizedDescription)\n", stderr)
  exit(1)
}
