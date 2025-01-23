    //
    //  main.swift
    //  binpack
    //
    //  Created by Denis Roenko on 10.12.2024.
    //

import Foundation
import CxxStdlib
import Cxx



struct Configuration {
    let sourcePath: String
    let destinationTemplate: String
    let scale: Int
    let padding: Int
}

struct ManifestElement: Codable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
    let pixelRatio: Int
}

typealias Manifest = [String: ManifestElement]

struct PackResult {
    let data: UnsafeMutableBufferPointer<UInt32>
    let rotatedImages: Int
    let manifest: Manifest
}


    // help
func printHelp() {
    print(
        """
        
        usage: binpack  sourcePath  destinationTemplate  scale  padding
                
        sourcePath:          path of SVG collection forder, eg: ~/Documents/icons_source, for current directory use .
        destinationTemplate: path to save atlases and manifests, eg: ~/Documents/generated/v1 or ./out/v2
        scale:               scale of pictures, should be integer, 1 for 1x, 2 for 2x, 3 for 3x
        padding:             count of clear pixels around all picture side, should be integer
        
        """
    )
}


    // arguments
func resolveArguments(fileManager: FileManager) -> Configuration {
        // check arguments and prepare to run
    let arguments = CommandLine.arguments
    guard arguments.count > 4 else {
        printHelp()
        exit(1)
    }
    let homePath = String(fileManager.homeDirectoryForCurrentUser.absoluteString.dropLast())
    let currentDirectoryPath = fileManager.currentDirectoryPath
    var sourceArgument = arguments[1].last == "/" ? String(arguments[1].dropLast()) : arguments[1]
    if sourceArgument.prefix(2) == ".." {
        let ups = sourceArgument.ranges(of: "../").count
        let uppedDirectoryPath = currentDirectoryPath.components(separatedBy: "/")
            .dropLast(ups)
            .joined(separator: "/")
        sourceArgument = uppedDirectoryPath + "/" + String(sourceArgument.dropFirst(ups * 3))
    }
    if sourceArgument.first == "." {
        sourceArgument = currentDirectoryPath + String(sourceArgument.dropFirst())
    }
    if sourceArgument.first == "~" {
        sourceArgument = ( homePath + String(sourceArgument.dropFirst()))
            .replacingOccurrences(of: "file://", with: "")
    }
    if sourceArgument.first != "/" {
        sourceArgument = (fileManager.currentDirectoryPath + "/" + sourceArgument)
            .replacingOccurrences(of: "file://", with: "")
    }
    let sourcePath = sourceArgument
    print("source path:", sourcePath)
    
    var destinationArgument = arguments[2].last == "/" ? String(arguments[2].dropLast()) : arguments[2]
    if destinationArgument.prefix(2) == ".." {
        let ups = destinationArgument.ranges(of: "../").count
        let uppedDirectoryPath = currentDirectoryPath.components(separatedBy: "/")
            .dropLast(ups)
            .joined(separator: "/")
        destinationArgument = uppedDirectoryPath + "/" + String(destinationArgument.dropFirst(ups * 3))
    }
    if destinationArgument.first == "." {
        destinationArgument = currentDirectoryPath + String(destinationArgument.dropFirst())
    }
    if destinationArgument.first == "~" {
        destinationArgument = (homePath + String(destinationArgument.dropFirst()))
            .replacingOccurrences(of: "file://", with: "")
    }
    if destinationArgument.first != "/" {
        destinationArgument = (fileManager.currentDirectoryPath + "/" + destinationArgument)
            .replacingOccurrences(of: "file://", with: "")
    }
    let destinationPath = destinationArgument
    print("destination:", destinationPath)
    
    let scale = Int(arguments[3]) ?? -1
    if scale == -1 {
        print("ERROR: unsupported argument for scale:", arguments[3])
        printHelp()
        exit(1)
    }
    print("scale:", scale)
    
    let padding = Int(arguments[4]) ?? -1
    if padding == -1 {
        print("ERROR: unsupported argument for padding:", arguments[4])
        printHelp()
        exit(1)
    }
    print("padding:", padding)
    return Configuration(sourcePath: sourcePath, destinationTemplate: destinationPath, scale: scale, padding: padding)
}


    // finding files in source path
func resolveFiles(sourcePath: String, fileManager: FileManager) -> [String] {
    let files = try! fileManager.contentsOfDirectory(atPath: sourcePath).filter { $0.hasSuffix("svg") }
    print("total files:", files.count)
    return files
    
}


    // bitmaps
func generateBitmaps(files: [String], sourcePath: String, scale: Int, padding: Int) -> [String: SvgCodeImage] {
    var images = [String: SvgCodeImage]()
    images.reserveCapacity(files.count)
    
        // generate images for each SVG with passed scale and padding
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
                    let size = originalWidth * MemoryLayout<UInt32>.stride
                    memcpy(newPixels.baseAddress!.advanced(by: containerStart), oldPixels.advanced(by: pixelsStart), size)
                }
            }
            oldPixels.deallocate()
            image.pixels = UnsafeMutableRawPointer(newPixels.baseAddress)!.assumingMemoryBound(to: CChar.self)
        }
        images[file] = image
    }
    print("total images:", images.count)
    return images
}


    // atlas size
func calculateAtlasSize(images: [String: SvgCodeImage], scale: Int) -> Int {
        // predicting atlas size
    let magicConstantForMaxRects = scale * 20 // don't touch!
    let square = images.values.reduce(0, { $0 + Int($1.width * $1.height) })
    var atlasSideSize = Int(sqrt(Double(square))) + magicConstantForMaxRects
    if atlasSideSize > 2048 { atlasSideSize = 2048 }
    return atlasSideSize
}


    // pack
func pack(images: inout [String:SvgCodeImage], atlasWidth: Int, atlasHeight: Int, scale: Int) -> PackResult {
    var cxxBinPack = MaxRectsBinPack()
    var cxxInput = InputVector()
    cxxInput.reserve(images.count)
    for image in images {
        cxxInput.push_back(BaseRectSize(name: std.string(image.key), width: image.value.width, height: image.value.height))
    }
    
    var cxxOutput = OutputVector()
    cxxBinPack.Init(Int32(atlasWidth), Int32(atlasHeight))
    cxxBinPack.Insert(&cxxInput, &cxxOutput, MaxRectsBinPack.FreeRectChoiceHeuristic(4)) // 4 - RectContactPointRule
    
    let placedImages = cxxBinPack.usedRectangles
    print("Placed images:", placedImages.count)
    
    var rotatedImages = 0
    var manifest = Manifest()
    manifest.reserveCapacity(images.count)
    
    let buffer = UnsafeMutableBufferPointer<UInt32>.allocate(capacity: atlasWidth * atlasHeight)
    buffer.initialize(repeating: 0)
    
    for image in placedImages {
        let fileName = String(image.name)
        guard let imageData = images[fileName],
              let name = fileName.components(separatedBy: ".").first,
              imageData.width == image.width,
              imageData.height == image.height
        else {
            rotatedImages += 1
            cxxInput.push_back(BaseRectSize(name: image.name, width: image.width, height: image.height))
            continue
        }
        let imageX = Int(image.x)
        let imageY = Int(image.y)
        let imageWidth = Int(image.width)
        let imageHeight = Int(image.height)
        imageData.pixels!.withMemoryRebound(to: UInt32.self, capacity: imageWidth * imageHeight) { pixels in
            for lineNumber in 0 ..< imageHeight {
                let pixelsStart = imageWidth * lineNumber
                let bufferStart = (imageY + lineNumber) * atlasWidth + imageX
                let size = imageWidth * MemoryLayout<UInt32>.stride
                memcpy(buffer.baseAddress!.advanced(by: bufferStart), pixels.advanced(by: pixelsStart), size)
            }
        }
        manifest[name] = ManifestElement(x: imageX, y: imageY, width: imageWidth, height: imageHeight, pixelRatio: scale)
        imageData.pixels.deallocate()
        images[fileName] = nil
    }
    return PackResult(data: buffer, rotatedImages: rotatedImages, manifest: manifest)
}


    // save
func writeAtlasToDisk(
    destinationTemplate: String,
    fileManager: FileManager,
    atlasWidth: Int,
    atlasHeight: Int,
    buffer: UnsafeMutableBufferPointer<UInt32>,
    scale: Int,
    atlasNumber: Int,
    manifest: Manifest
) {
    let pathOfTemplate = destinationTemplate.components(separatedBy: "/").dropLast().joined(separator: "/")
    if !fileManager.fileExists(atPath: pathOfTemplate) {
        try! fileManager.createDirectory(atPath: pathOfTemplate, withIntermediateDirectories: true)
    }
    let counter = atlasNumber == 0 ? "" : "_\(atlasNumber)"
    let filenameTemplate = destinationTemplate + "\(scale == 1 ? "" : "@\(scale)x")" + counter
    let channelsCount = 4 // RGBA
    stbi_write_png(filenameTemplate + ".png", Int32(atlasWidth), Int32(atlasHeight), Int32(channelsCount), buffer.baseAddress, Int32(atlasWidth * channelsCount))
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.withoutEscapingSlashes, .prettyPrinted, .sortedKeys]
    let manifestData = try! encoder.encode(manifest)
    let manifestURL = URL(fileURLWithPath: filenameTemplate + ".json")
    try! manifestData.write(to: manifestURL)
    buffer.deallocate()
}


    // main
func main() {
    let fileManager = FileManager.default
    let configuration = resolveArguments(fileManager: fileManager)
    let files = resolveFiles(sourcePath: configuration.sourcePath, fileManager: fileManager)
    guard !files.isEmpty else {
        print("ERROR: no .svg files found in \(configuration.sourcePath)")
        exit(1)
    }
    var images = generateBitmaps(
        files: files,
        sourcePath: configuration.sourcePath,
        scale: configuration.scale,
        padding: configuration.padding
    )
    print("-------------")
    var atlasNumber = 0
        // main cycle
    while images.count > 0 {
        let atlasSideSize = calculateAtlasSize(images: images, scale: configuration.scale)
        let atlasWidth = atlasSideSize
        let atlasHeight = atlasSideSize
        print("atlas size:", atlasWidth, atlasHeight)
        let packResult = pack(images: &images, atlasWidth: atlasWidth, atlasHeight: atlasHeight, scale: configuration.scale)
        print(
        """
        pack result: 
            rotated images: \(packResult.rotatedImages)
            not in atlas: \(images.count)
        """
        )
        writeAtlasToDisk(
            destinationTemplate: configuration.destinationTemplate,
            fileManager: fileManager,
            atlasWidth: atlasWidth,
            atlasHeight: atlasHeight,
            buffer: packResult.data,
            scale: configuration.scale,
            atlasNumber: atlasNumber,
            manifest: packResult.manifest
        )
        print("-------------")
        atlasNumber += 1
    }
    
    print("finished, check results at", configuration.destinationTemplate + "*")
}


    // run
main()
