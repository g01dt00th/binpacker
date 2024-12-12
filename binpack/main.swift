//
//  main.swift
//  binpack
//
//  Created by  on 10.12.2024.
//

import Foundation
import CxxStdlib
import Cxx

let arguments = CommandLine.arguments
guard arguments.count == 5 else {
    exit(1)
}
let sourcePath = arguments[1]
print("source path:", sourcePath)

let destinationFile = arguments[2]
print("destination:", destinationFile)

let scale = Int(arguments[3])!
print("scale:", scale)

let padding = Int(arguments[4])!
print("padding:", padding)

let fm = FileManager.default
let files = try! fm.contentsOfDirectory(atPath: sourcePath)
print("total files:", files.count)
var images = [String: SvgCodeImage]()
images.reserveCapacity(files.count)

for file in files {
    let path = sourcePath + "/" + file
    let source = try! String(contentsOfFile: path, encoding: .utf8)
    var imageSize = SvgSize(width: 0, height: 0)
    imageSize = getSVGImageSize(source)
    imageSize.width = imageSize.width * Int32(scale)
    imageSize.height = imageSize.height * Int32(scale)
    var image = SvgCodeImage()
    generateSVGImage(source, &image, imageSize.width, imageSize.height)
    guard image.pixels != nil else { fatalError() }
    if padding != 0 {
        let value = Int32(padding * 2)
        // original values
        let originalWidth = Int(image.width)
        let originalHeight = Int(image.height)
        
        // new values
        image.width += value
        image.height += value
        image.totalWidth += value
        image.totalHeight += value
        let oldPixels = image.pixels!
        
        
        let imageX = padding
        let imageY = padding
        let containerWidth = Int(image.width)
        let containerHeight = Int(image.height)
        
        let newPixels = UnsafeMutableBufferPointer<UInt32>.allocate(capacity: containerWidth * containerHeight)
        newPixels.initialize(repeating: 0)

        oldPixels.withMemoryRebound(to: UInt32.self, capacity: originalWidth * originalHeight) { oldPixels in
            for lineNumber in 0 ..< originalHeight {
                let pixelsStart = originalWidth * lineNumber
                let containerStart = (imageY + lineNumber) * containerWidth + imageX
                let size = originalWidth * MemoryLayout<UInt32>.size
                memcpy(newPixels.baseAddress!.advanced(by: containerStart), oldPixels.advanced(by: pixelsStart), size)
            }
        }
        oldPixels.deallocate()
        image.pixels = UnsafeMutableRawPointer(newPixels.baseAddress)!.assumingMemoryBound(to: CChar.self)
    }
    images[file] = image
}

let finalWidth = 2048
let finalHeight = 2048

print("total images:", images.count)
var cxxBinPack = MaxRectsBinPack(Int32(finalWidth), Int32(finalHeight))
var cxxInput = InputVector()
cxxInput.reserve(images.count)
for image in images {
    cxxInput.push_back(BaseRectSize(name: std.string(image.key), width: image.value.width, height: image.value.height))
}

var cxxOutput = OutputVector()
cxxBinPack.Insert(&cxxInput, &cxxOutput, MaxRectsBinPack.FreeRectChoiceHeuristic(4))
print("not in first atlas:", cxxInput.count)
for input in cxxInput {
    print(input)
}

let placedImages = cxxBinPack.usedRectangles
print("Placed images:", placedImages.count)

let channelsCount = 4 // RGBA
var rotatedImages = 0

let buffer = UnsafeMutableBufferPointer<UInt32>.allocate(capacity: finalWidth * finalHeight)
buffer.initialize(repeating: 0)

for image in placedImages {
    let fileName = String(image.name)
    guard let imageData = images[fileName]//,
//          let name = fileName.components(separatedBy: ".").first
    else { continue }
    guard imageData.width == image.width,
          imageData.height == image.height
    else {
        rotatedImages += 1
        continue
    }
    let imageX = Int(image.x)
    let imageY = Int(image.y)
    let imageWidth = Int(image.width)
    let imageHeight = Int(image.height)
    imageData.pixels!.withMemoryRebound(to: UInt32.self, capacity: imageWidth * imageHeight) { pixels in
        for lineNumber in 0 ..< imageHeight {
            let pixelsStart = imageWidth * lineNumber
            let bufferStart = (imageY + lineNumber) * finalWidth + imageX
            let size = imageWidth * MemoryLayout<UInt32>.size
            memcpy(buffer.baseAddress!.advanced(by: bufferStart), pixels.advanced(by: pixelsStart), size)
        }
    }
}

stbi_write_png(destinationFile + "/output.png", Int32(finalWidth), Int32(finalHeight), Int32(channelsCount), buffer.baseAddress, Int32(finalWidth * channelsCount))

buffer.deallocate()
images.forEach { $0.value.pixels.deallocate() }
print("rotated images:", rotatedImages)
