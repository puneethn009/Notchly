import Cocoa

let args = CommandLine.arguments
if args.count < 2 { exit(1) }
let imagePath = args[1]

guard let img = NSImage(contentsOfFile: imagePath),
      let cgImage = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("Could not load image")
    exit(1)
}

let width = cgImage.width
let height = cgImage.height
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bytesPerPixel = 4
let bytesPerRow = bytesPerPixel * width
let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

guard let context = CGContext(data: nil,
                              width: width,
                              height: height,
                              bitsPerComponent: 8,
                              bytesPerRow: bytesPerRow,
                              space: colorSpace,
                              bitmapInfo: bitmapInfo) else {
    print("Could not create context")
    exit(1)
}

context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

guard let data = context.data else { exit(1) }
let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)

for i in 0..<(width * height) {
    let offset = i * bytesPerPixel
    let r = buffer[offset]
    let g = buffer[offset + 1]
    let b = buffer[offset + 2]
    
    // If it's near black, make it transparent
    if r < 30 && g < 30 && b < 30 {
        buffer[offset] = 0
        buffer[offset+1] = 0
        buffer[offset+2] = 0
        buffer[offset+3] = 0
    }
}

guard let outputCGImage = context.makeImage() else { exit(1) }
let outputImage = NSImage(cgImage: outputCGImage, size: NSSize(width: width, height: height))

guard let tiffData = outputImage.tiffRepresentation,
      let bitmapImage = NSBitmapImageRep(data: tiffData),
      let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
    print("Could not create PNG")
    exit(1)
}

try? pngData.write(to: URL(fileURLWithPath: imagePath))
print("Done")
