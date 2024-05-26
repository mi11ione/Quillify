import MetalKit
import PencilKit
import simd
import SwiftUI
import UIKit

private struct Point: Hashable {
    let x, y: Int
}

class ImagePathConverter {
    struct Pixel {
        let x, y: Int
        let r, g, b, a: UInt8
    }

    let image: UIImage
    private var rgbaPixelData: [UInt8]?

    init(image: UIImage) {
        self.image = image
        self.rgbaPixelData = image.rgbaPixelData()
    }

    private lazy var groupedConnectedPixels: [Set<Point>] = {
        do {
            return try self.findGroupedConnectedPixels()
        } catch {
            return []
        }
    }()

    private lazy var centerLines: [Set<Point>] = self.findCenterLines()

    public func findPaths() -> [([CGPoint], UIColor)] {
        var brightness: CGFloat = 0
        (image.cgImage?.averageColor ?? .white).getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)
        let averageBrightness = Float(brightness)
        let centerLinePaths = findCenterLinePaths()
        var pathColors = [[([CGPoint], UIColor)]](repeating: [], count: centerLinePaths.count)

        DispatchQueue.concurrentPerform(iterations: centerLinePaths.count) { index in
            let path = centerLinePaths[index]
            let color: UIColor = averageColor(path: path)
            let pointData = path.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
            let newColor = averageBrightness > 0.5 ? color : SemanticColor.invertedBrightnessColor(color: color)
            pathColors[index] = [(pointData, newColor)]
        }

        return pathColors.flatMap { $0 }
    }

    private func pixelAtPoint(_ p: Point) -> Pixel? {
        let imageIndex: Int = (p.y * Int(image.size.width)) + p.x
        guard let pixelData = rgbaPixelData, imageIndex >= 0, imageIndex < pixelData.count / 4 else {
            return nil
        }
        return Pixel(
            x: p.x, y: p.y,
            r: pixelData[imageIndex * 4],
            g: pixelData[imageIndex * 4 + 1],
            b: pixelData[imageIndex * 4 + 2],
            a: pixelData[imageIndex * 4 + 3]
        )
    }

    private func findGroupedConnectedPixels() throws -> [Set<Point>] {
        guard let cgImage = image.cgImage else { return [] }
        let covarianceFilter = try PathDetectionKernel(cgImage: cgImage)
        let outputImage = try covarianceFilter.applyKernel()
        let size = image.size
        guard let outputData = UIImage(cgImage: outputImage).rgbaPixelData() else { return [] }

        let numPixels = Int(size.width) * Int(size.height)
        var growingStrokePixelArray = [Point]()
        let concurrentQueue = DispatchQueue(label: "com.quillify.growingStrokePixelArray", attributes: .concurrent)
        let dispatchGroup = DispatchGroup()

        DispatchQueue.concurrentPerform(iterations: numPixels) { index in
            let startIndex = index * 4
            guard outputData[startIndex] > 100 else { return }
            let x = index % Int(self.image.size.width)
            let y = index / Int(self.image.size.width)
            let point = Point(x: x, y: y)
            
            dispatchGroup.enter()
            concurrentQueue.async(flags: .barrier) {
                growingStrokePixelArray.append(point)
                dispatchGroup.leave()
            }
        }

        dispatchGroup.wait()

        let strokePixels = growingStrokePixelArray
        let strokesSet = Set<Point>(strokePixels)
        var groups = [Set<Point>]()
        var visited = Set<Point>()

        for point in strokePixels {
            guard !visited.contains(point) else { continue }
            var stroke = Set<Point>()
            var searchPoints = [point]
            stroke.insert(point)

            while !searchPoints.isEmpty {
                guard let searchPoint = searchPoints.popLast() else { break }
                let neighbors = [Point(x: searchPoint.x, y: searchPoint.y - 1),
                                 Point(x: searchPoint.x - 1, y: searchPoint.y),
                                 Point(x: searchPoint.x + 1, y: searchPoint.y),
                                 Point(x: searchPoint.x, y: searchPoint.y + 1)].filter {
                                    strokesSet.contains($0) && !visited.contains($0)
                                 }
                searchPoints.append(contentsOf: neighbors)
                stroke.insert(searchPoint)
                visited.insert(searchPoint)
            }
            groups.append(stroke)
        }
        return groups
    }

    private func findCenterLines() -> [Set<Point>] {
        var centerLines = [Set<Point>](repeating: Set<Point>(), count: groupedConnectedPixels.count)
        DispatchQueue.concurrentPerform(iterations: groupedConnectedPixels.count) { index in
            let group = groupedConnectedPixels[index]
            var boundaries = Set<Point>()
            for point in group {
                if [Point(x: point.x, y: point.y - 1),
                    Point(x: point.x - 1, y: point.y),
                    Point(x: point.x + 1, y: point.y),
                    Point(x: point.x, y: point.y + 1)].contains(where: { !group.contains($0) }) {
                    boundaries.insert(point)
                }
            }
            var updatedBoundaries = boundaries
            var updatedGroup = group
            var didChange = true

            while didChange {
                didChange = false
                for boundary in updatedBoundaries {
                    guard updatedBoundaries.contains(boundary),
                          !Connectivity.instance.isRequiredForConnectivity(point: boundary, group: updatedGroup) else { continue }

                    [Point(x: boundary.x, y: boundary.y - 1),
                     Point(x: boundary.x - 1, y: boundary.y),
                     Point(x: boundary.x + 1, y: boundary.y),
                     Point(x: boundary.x, y: boundary.y + 1),
                     Point(x: boundary.x - 1, y: boundary.y - 1),
                     Point(x: boundary.x + 1, y: boundary.y - 1),
                     Point(x: boundary.x - 1, y: boundary.y + 1),
                     Point(x: boundary.x + 1, y: boundary.y + 1)].forEach {
                        if updatedGroup.contains($0) {
                            updatedBoundaries.insert($0)
                        }
                    }
                    updatedBoundaries.remove(boundary)
                    updatedGroup.remove(boundary)
                    didChange = true
                }
            }
            centerLines[index] = updatedGroup
        }
        return centerLines
    }

    private func findCenterLinePaths() -> [[Point]] {
        var paths = [[[Point]]](repeating: [], count: centerLines.count)
        DispatchQueue.concurrentPerform(iterations: centerLines.count) { index in
            let centerLineSet = centerLines[index]
            guard let initialPoint = centerLineSet.min(by: { $0.x + $0.y < $1.x + $1.y }) else { return }
            let deque = Deque<Point>()
            let findNeighbors: (Point) -> [Point] = { point in
                return [Point(x: point.x, y: point.y - 1),
                        Point(x: point.x - 1, y: point.y),
                        Point(x: point.x + 1, y: point.y),
                        Point(x: point.x, y: point.y + 1),
                        Point(x: point.x - 1, y: point.y - 1),
                        Point(x: point.x + 1, y: point.y - 1),
                        Point(x: point.x - 1, y: point.y + 1),
                        Point(x: point.x + 1, y: point.y + 1)].filter { centerLineSet.contains($0) }
            }
            deque.addAtTail(initialPoint)
            var breadthVisited = Set<Point>()
            breadthVisited.insert(initialPoint)
            guard var currentPoint = deque.popFirst() else { return }

            while !Connectivity.instance.isEdge(point: currentPoint, group: centerLineSet) {
                let neighbors = findNeighbors(currentPoint).filter { !breadthVisited.contains($0) }
                neighbors.forEach { deque.addAtTail($0) }
                guard let nextPoint = deque.popFirst() else { break }
                currentPoint = nextPoint
                breadthVisited.insert(nextPoint)
            }

            let startingPoint = currentPoint
            var depthVisited = Set<Point>()
            var stack: [Point] = []
            var currentDepth = startingPoint
            var currentPath: [Point] = [startingPoint]
            var centerLinePaths = [[Point]]()

            while true {
                let neighbors = findNeighbors(currentDepth)
                stack.append(contentsOf: neighbors.filter { !depthVisited.contains($0) })
                guard let nextPoint = stack.popLast() else { break }

                if neighbors.contains(nextPoint), neighbors.count < 3 {
                    currentPath.append(nextPoint)
                    currentDepth = nextPoint
                    depthVisited.insert(nextPoint)
                } else {
                    centerLinePaths.append(currentPath)
                    currentPath = [nextPoint]
                    currentDepth = nextPoint
                    depthVisited.insert(nextPoint)
                }
            }
            centerLinePaths.append(currentPath)
            paths[index] = centerLinePaths
        }
        return paths.flatMap { $0 }
    }

    private func averageColor(path: [Point]) -> UIColor {
        let numSamplePoints = min(10, path.count)
        let sampleIndices = (0..<numSamplePoints).map { _ in Int.random(in: 0..<path.count) }
        let sampleColors = sampleIndices.compactMap { index -> (r: CGFloat, g: CGFloat, b: CGFloat)? in
            let samplePoint = path[index]
            guard let pixel = pixelAtPoint(samplePoint) else { return nil }
            return (CGFloat(pixel.r) / 255.0, CGFloat(pixel.g) / 255.0, CGFloat(pixel.b) / 255.0)
        }
        let sumColors = sampleColors.reduce((r: 0.0, g: 0.0, b: 0.0)) { colorSum, color in
            return (colorSum.r + color.r, colorSum.g + color.g, colorSum.b + color.b)
        }
        return UIColor(
            red: sumColors.r / CGFloat(numSamplePoints),
            green: sumColors.g / CGFloat(numSamplePoints),
            blue: sumColors.b / CGFloat(numSamplePoints),
            alpha: 1.0
        )
    }
}

private class Connectivity {
    static let instance = Connectivity()
    private let queue = DispatchQueue(label: "connectivity", qos: .userInitiated, autoreleaseFrequency: .workItem, target: nil)

    private lazy var _edgeMasks: [simd_float3x3] = {
        let lastHorizontal: simd_float3x3 = {
            let col0 = simd_float3(-1, -1, -1)
            let col1 = simd_float3(1, 1, -1)
            let col2 = simd_float3(-1, -1, -1)
            return simd_float3x3(col0, col1, col2)
        }()
        return fourRotations(matrix: lastHorizontal)
    }()

    private var edgeMasks: [simd_float3x3] {
        queue.sync { _edgeMasks }
    }

    private func fourRotations(matrix: simd_float3x3) -> [simd_float3x3] {
        func rotateMatrix(matrix: simd_float3x3) -> simd_float3x3 {
            let (col0, col1, col2) = matrix.columns
            let newCol0 = simd_float3(col0.z, col1.z, col2.z)
            let newCol1 = simd_float3(col0.y, col1.y, col2.y)
            let newCol2 = simd_float3(col0.x, col1.x, col2.x)
            return simd_float3x3(newCol0, newCol1, newCol2)
        }
        let rot0 = matrix
        let rot1 = rotateMatrix(matrix: matrix)
        let rot2 = rotateMatrix(matrix: rot1)
        let rot3 = rotateMatrix(matrix: rot2)
        return [rot0, rot1, rot2, rot3]
    }

    private lazy var _hitMissMasks: [simd_float3x3] = {
        var masks = [simd_float3x3]()

        let horizontal: simd_float3x3 = {
            let col0 = simd_float3(-1, -1, -1)
            let col1 = simd_float3(1, 1, -1)
            let col2 = simd_float3(-1, -1, -1)
            return simd_float3x3(col0, col1, col2)
        }()

        let topLeft: simd_float3x3 = {
            let col0 = simd_float3(1, 0, 0)
            let col1 = simd_float3(0, 1, -1)
            let col2 = simd_float3(0, -1, 1)
            return simd_float3x3(col0, col1, col2)
        }()

        let topCenter: simd_float3x3 = {
            let col0 = simd_float3(0, 0, 0)
            let col1 = simd_float3(1, 1, -1)
            let col2 = simd_float3(0, -1, 1)
            return simd_float3x3(col0, col1, col2)
        }()

        let topRight: simd_float3x3 = {
            let col0 = simd_float3(0, -1, 1)
            let col1 = simd_float3(1, 1, -1)
            let col2 = simd_float3(0, 0, 0)
            return simd_float3x3(col0, col1, col2)
        }()

        let bottomLeft0: simd_float3x3 = {
            let col0 = simd_float3(0, -1, 0)
            let col1 = simd_float3(1, 1, 1)
            let col2 = simd_float3(0, -1, 0)
            return simd_float3x3(col0, col1, col2)
        }()

        let bottomLeft1: simd_float3x3 = {
            let col0 = simd_float3(0, 1, 0)
            let col1 = simd_float3(-1, 1, -1)
            let col2 = simd_float3(0, 1, 0)
            return simd_float3x3(col0, col1, col2)
        }()

        let bottomMiddle: simd_float3x3 = {
            let col0 = simd_float3(0, -1, 1)
            let col1 = simd_float3(0, 1, -1)
            let col2 = simd_float3(0, -1, 1)
            return simd_float3x3(col0, col1, col2)
        }()

        let bottomRight: simd_float3x3 = {
            let col0 = simd_float3(0, 1, 0)
            let col1 = simd_float3(1, 1, 1)
            let col2 = simd_float3(0, 1, 0)
            return simd_float3x3(col0, col1, col2)
        }()

        masks.append(contentsOf: fourRotations(matrix: horizontal))
        masks.append(contentsOf: fourRotations(matrix: topLeft))
        masks.append(contentsOf: fourRotations(matrix: topCenter))
        masks.append(contentsOf: fourRotations(matrix: topRight))
        masks.append(bottomLeft0)
        masks.append(bottomLeft1)
        masks.append(contentsOf: fourRotations(matrix: bottomMiddle))
        masks.append(bottomRight)

        return masks
    }()

    private var hitMissMasks: [simd_float3x3] {
        queue.sync { _hitMissMasks }
    }

    private func isRequired(point: Point, group: Set<Point>) -> (simd_float3x3) -> Bool {
        let neighbors = [
            Point(x: point.x - 1, y: point.y - 1), Point(x: point.x, y: point.y - 1), Point(x: point.x + 1, y: point.y - 1),
            Point(x: point.x - 1, y: point.y),     Point(x: point.x, y: point.y),     Point(x: point.x + 1, y: point.y),
            Point(x: point.x - 1, y: point.y + 1), Point(x: point.x, y: point.y + 1), Point(x: point.x + 1, y: point.y + 1)
        ].map { group.contains($0) ? Float(1) : Float(-1) }

        let matrix = simd_float3x3(rows: [
            SIMD3<Float>(neighbors[0], neighbors[1], neighbors[2]),
            SIMD3<Float>(neighbors[3], neighbors[4], neighbors[5]),
            SIMD3<Float>(neighbors[6], neighbors[7], neighbors[8])
        ])

        return { mask in
            let multipliedColumns = simd_float3x3(
                mask.columns.0 * matrix.columns.0,
                mask.columns.1 * matrix.columns.1,
                mask.columns.2 * matrix.columns.2
            )
            let absoluteMask = simd_float3x3(
                simd_abs(mask.columns.0),
                simd_abs(mask.columns.1),
                simd_abs(mask.columns.2)
            )
            return multipliedColumns == absoluteMask
        }
    }

    func isEdge(point: Point, group: Set<Point>) -> Bool {
        return edgeMasks.contains(where: isRequired(point: point, group: group))
    }

    func isRequiredForConnectivity(point: Point, group: Set<Point>) -> Bool {
        return hitMissMasks.contains(where: isRequired(point: point, group: group))
    }
}

private extension UIImage {
    func rgbaPixelData() -> [UInt8]? {
        let size = size
        var pixelData = [UInt8](repeating: 0, count: Int(size.width * size.height * 4))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &pixelData, width: Int(size.width), height: Int(size.height),
                                bitsPerComponent: 8, bytesPerRow: 4 * Int(size.width), space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let cgImage = cgImage else { return nil }
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        return pixelData
    }
}

private class TextureManager {
    enum TextureErrors: Error {
        case cgImageConversionFailed
        case textureCreationFailed
    }

    private let textureLoader: MTKTextureLoader

    init(device: MTLDevice) {
        textureLoader = MTKTextureLoader(device: device)
    }

    func texture(cgImage: CGImage, usage: MTLTextureUsage = [.shaderRead, .shaderWrite]) throws -> MTLTexture {
        let options: [MTKTextureLoader.Option: Any] = [
            .textureUsage: NSNumber(value: usage.rawValue),
            .generateMipmaps: NSNumber(value: false),
            .SRGB: NSNumber(value: false),
        ]
        return try textureLoader.newTexture(cgImage: cgImage, options: options)
    }

    func cgImage(texture: MTLTexture) throws -> CGImage {
        let bytesPerRow = texture.width * 4
        let bytesLength = bytesPerRow * texture.height
        let rgbaBytes = UnsafeMutableRawPointer.allocate(byteCount: bytesLength, alignment: MemoryLayout<UInt8>.alignment)
        defer { rgbaBytes.deallocate() }

        let region = MTLRegion(origin: .init(x: 0, y: 0, z: 0), size: .init(width: texture.width, height: texture.height, depth: texture.depth))

        texture.getBytes(rgbaBytes, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitMapInfo = CGBitmapInfo(rawValue: CGImageByteOrderInfo.order32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)

        guard let data = CFDataCreate(nil, rgbaBytes.assumingMemoryBound(to: UInt8.self), bytesLength),
              let dataProvider = CGDataProvider(data: data),
              let cgImage = CGImage(width: texture.width, height: texture.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitMapInfo, provider: dataProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else {
            throw TextureErrors.cgImageConversionFailed
        }
        return cgImage
    }

    func createMatchingTexture(texture: MTLTexture) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.width = texture.width
        descriptor.height = texture.height
        descriptor.pixelFormat = texture.pixelFormat
        descriptor.storageMode = texture.storageMode
        descriptor.usage = texture.usage

        guard let matchingTexture = textureLoader.device.makeTexture(descriptor: descriptor) else { throw TextureErrors.textureCreationFailed }
        return matchingTexture
    }
}

private final class PathDetectionKernel {
    private let library: MTLLibrary
    private let textureManager: TextureManager
    private let imageTexture: MTLTexture
    private let outputTexture: MTLTexture
    private var size: Float = 2
    private var commandQueue: MTLCommandQueue
    private let pipelineState: MTLComputePipelineState
    private let averageBrightness: Float

    private var deviceSupportsNonuniformThreadgroups: Bool

    init(cgImage: CGImage) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let library = device.makeDefaultLibrary() else { throw MetalErrors.deviceCreationFailed }
        let textureManager = TextureManager(device: device)
        self.library = library
        var brightness: CGFloat = 0
        (cgImage.averageColor ?? .white).getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)
        averageBrightness = Float(brightness)
        guard let commandQueue = library.device.makeCommandQueue() else { throw MetalErrors.commandQueueCreationFailed }
        self.commandQueue = commandQueue
        deviceSupportsNonuniformThreadgroups = library.device.supportsFamily(.apple5)
        let constantValues = MTLFunctionConstantValues()

        constantValues.setConstantValue(&deviceSupportsNonuniformThreadgroups, type: .bool, index: 0)
        let function = try library.makeFunction(name: "correlation_filter", constantValues: constantValues)
        pipelineState = try library.device.makeComputePipelineState(function: function)
        self.textureManager = textureManager
        let inputTexture = try textureManager.texture(cgImage: cgImage)
        imageTexture = inputTexture
        outputTexture = try textureManager.createMatchingTexture(texture: inputTexture)
    }

    private func encode(source: MTLTexture, destination: MTLTexture, in commandBuffer: MTLCommandBuffer) {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        encoder.setTexture(source, index: 0)
        encoder.setTexture(destination, index: 1)
        encoder.setBytes(&size, length: MemoryLayout<Float>.stride, index: 0)

        let gridSize = MTLSize(width: source.width, height: source.height, depth: 1)
        let threadGroupWidth = pipelineState.threadExecutionWidth
        let threadGroupHeight = pipelineState.maxTotalThreadsPerThreadgroup / threadGroupWidth
        let threadGroupSize = MTLSize(width: threadGroupWidth, height: threadGroupHeight, depth: 1)

        encoder.setComputePipelineState(pipelineState)

        if deviceSupportsNonuniformThreadgroups {
            encoder.dispatchThreads(gridSize,
                                    threadsPerThreadgroup: threadGroupSize)
        } else {
            let threadGroupCount = MTLSize(width: (gridSize.width + threadGroupSize.width - 1) / threadGroupSize.width,
                                           height: (gridSize.height + threadGroupSize.height - 1) / threadGroupSize.height,
                                           depth: 1)
            encoder.dispatchThreadgroups(threadGroupCount,
                                         threadsPerThreadgroup: threadGroupSize)
        }
        encoder.endEncoding()
    }

    func applyKernel() throws -> CGImage {
        var kernelImages = [CGImage]()
        let sizes: [Float] = [2, 4, 8, 16, 32]

        for size in sizes {
            self.size = size
            guard let commandBuffer = commandQueue.makeCommandBuffer() else { throw MetalErrors.commandBufferCreationFailed }
            encode(source: imageTexture, destination: outputTexture, in: commandBuffer)
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            kernelImages.append(try textureManager.cgImage(texture: outputTexture))
        }

        guard let combinedImage = kernelImages.reduce(nil as CGImage?, { lastImage, nextImage in
            guard let previousImage = lastImage else { return nextImage }
            guard let combiner = try? CombineImageKernel(cgImageOne: previousImage, cgImageTwo: nextImage, library: library, textureManager: textureManager) else { return nil }
            return try? combiner.applyKernel()
        }) else { throw MetalErrors.kernelFailed }

        let binaryFilter = try BinaryImageKernel(cgImage: combinedImage, library: library, textureManager: textureManager)
        let binaryImage = try binaryFilter.getBinaryImage()
        let originalImage = try textureManager.cgImage(texture: imageTexture)

        let averageBrightnessFilter = try FilterNearAverageKernel(cgImageOne: originalImage, cgImageTwo: binaryImage, averageBrightness: averageBrightness, library: library, textureManager: textureManager)
        let filteredImage = try averageBrightnessFilter.applyKernel()

        let addMissingPixels = try RecoverMissingPixelsKernel(cgImageOne: originalImage, cgImageTwo: filteredImage, averageBrightness: averageBrightness, library: library, textureManager: textureManager)
        return try addMissingPixels.applyKernel()
    }

    final class CombineImageKernel {
        private let textureManager: TextureManager
        private let inputTextureOne: MTLTexture
        private let inputTextureTwo: MTLTexture
        private let outputTexture: MTLTexture
        private var commandQueue: MTLCommandQueue
        private let pipelineState: MTLComputePipelineState
        private var deviceSupportsNonuniformThreadgroups: Bool

        init(cgImageOne: CGImage, cgImageTwo: CGImage, library: MTLLibrary, textureManager: TextureManager) throws {
            guard let commandQueue = library.device.makeCommandQueue() else { throw MetalErrors.commandQueueCreationFailed }
            self.commandQueue = commandQueue
            deviceSupportsNonuniformThreadgroups = library.device.supportsFamily(.apple5)
            let constantValues = MTLFunctionConstantValues()
            constantValues.setConstantValue(&deviceSupportsNonuniformThreadgroups, type: .bool, index: 0)
            let function = try library.makeFunction(name: "combine_confidence", constantValues: constantValues)
            pipelineState = try library.device.makeComputePipelineState(function: function)
            self.textureManager = textureManager
            inputTextureOne = try textureManager.texture(cgImage: cgImageOne)
            inputTextureTwo = try textureManager.texture(cgImage: cgImageTwo)
            outputTexture = try textureManager.createMatchingTexture(texture: inputTextureOne)
        }

        func applyKernel() throws -> CGImage {
            guard let commandBuffer = commandQueue.makeCommandBuffer() else { throw MetalErrors.commandBufferCreationFailed }
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else { throw MetalErrors.encoderCreationFailed }

            encoder.setTexture(inputTextureOne, index: 0)
            encoder.setTexture(inputTextureTwo, index: 1)
            encoder.setTexture(outputTexture, index: 2)
            let gridSize = MTLSize(width: inputTextureOne.width, height: inputTextureOne.height, depth: 1)
            let threadGroupWidth = pipelineState.threadExecutionWidth
            let threadGroupHeight = pipelineState.maxTotalThreadsPerThreadgroup / threadGroupWidth
            let threadGroupSize = MTLSize(width: threadGroupWidth, height: threadGroupHeight, depth: 1)

            encoder.setComputePipelineState(pipelineState)
            if deviceSupportsNonuniformThreadgroups {
                encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
            } else {
                let threadGroupCount = MTLSize(width: (gridSize.width + threadGroupSize.width - 1) / threadGroupSize.width,
                                               height: (gridSize.height + threadGroupSize.height - 1) / threadGroupSize.height,
                                               depth: 1)
                encoder.dispatchThreadgroups(threadGroupCount, threadsPerThreadgroup: threadGroupSize)
            }
            encoder.endEncoding()

            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            return try textureManager.cgImage(texture: outputTexture)
        }
    }

    final class BinaryImageKernel {
        private let textureManager: TextureManager
        private let inputTexture: MTLTexture
        private let outputTexture: MTLTexture
        private var commandQueue: MTLCommandQueue
        private let pipelineState: MTLComputePipelineState
        private var deviceSupportsNonuniformThreadgroups: Bool

        init(cgImage: CGImage, library: MTLLibrary, textureManager: TextureManager) throws {
            guard let commandQueue = library.device.makeCommandQueue() else { throw MetalErrors.commandQueueCreationFailed }
            self.commandQueue = commandQueue
            deviceSupportsNonuniformThreadgroups = library.device.supportsFamily(.apple5)
            let constantValues = MTLFunctionConstantValues()
            constantValues.setConstantValue(&deviceSupportsNonuniformThreadgroups, type: .bool, index: 0)
            let function = try library.makeFunction(name: "threshold_filter", constantValues: constantValues)
            pipelineState = try library.device.makeComputePipelineState(function: function)
            self.textureManager = textureManager
            inputTexture = try textureManager.texture(cgImage: cgImage)
            outputTexture = try textureManager.createMatchingTexture(texture: inputTexture)
        }

        func getBinaryImage() throws -> CGImage {
            guard let commandBuffer = commandQueue.makeCommandBuffer() else { throw MetalErrors.commandBufferCreationFailed }
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else { throw MetalErrors.encoderCreationFailed }

            encoder.setTexture(inputTexture, index: 0)
            encoder.setTexture(outputTexture, index: 1)
            let gridSize = MTLSize(width: inputTexture.width, height: inputTexture.height, depth: 1)
            let threadGroupWidth = pipelineState.threadExecutionWidth
            let threadGroupHeight = pipelineState.maxTotalThreadsPerThreadgroup / threadGroupWidth
            let threadGroupSize = MTLSize(width: threadGroupWidth, height: threadGroupHeight, depth: 1)

            encoder.setComputePipelineState(pipelineState)
            if deviceSupportsNonuniformThreadgroups {
                encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
            } else {
                let threadGroupCount = MTLSize(width: (gridSize.width + threadGroupSize.width - 1) / threadGroupSize.width,
                                               height: (gridSize.height + threadGroupSize.height - 1) / threadGroupSize.height,
                                               depth: 1)
                encoder.dispatchThreadgroups(threadGroupCount, threadsPerThreadgroup: threadGroupSize)
            }
            encoder.endEncoding()

            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            return try textureManager.cgImage(texture: outputTexture)
        }
    }

    final class FilterNearAverageKernel {
        private let textureManager: TextureManager
        private let inputTextureOne: MTLTexture
        private let inputTextureTwo: MTLTexture
        private let outputTexture: MTLTexture
        private var averageBrightness: Float
        private var commandQueue: MTLCommandQueue
        private let pipelineState: MTLComputePipelineState
        private var deviceSupportsNonuniformThreadgroups: Bool

        init(cgImageOne: CGImage, cgImageTwo: CGImage, averageBrightness: Float, library: MTLLibrary, textureManager: TextureManager) throws {
            guard let commandQueue = library.device.makeCommandQueue() else { throw MetalErrors.commandQueueCreationFailed }
            self.commandQueue = commandQueue
            deviceSupportsNonuniformThreadgroups = library.device.supportsFamily(.apple5)
            let constantValues = MTLFunctionConstantValues()
            constantValues.setConstantValue(&deviceSupportsNonuniformThreadgroups, type: .bool, index: 0)
            let function = try library.makeFunction(name: "differs_from_average_brightness", constantValues: constantValues)
            pipelineState = try library.device.makeComputePipelineState(function: function)
            self.textureManager = textureManager
            inputTextureOne = try textureManager.texture(cgImage: cgImageOne)
            inputTextureTwo = try textureManager.texture(cgImage: cgImageTwo)
            outputTexture = try textureManager.createMatchingTexture(texture: inputTextureOne)
            self.averageBrightness = averageBrightness
        }

        func applyKernel() throws -> CGImage {
            guard let commandBuffer = commandQueue.makeCommandBuffer() else { throw MetalErrors.commandBufferCreationFailed }
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else { throw MetalErrors.encoderCreationFailed }

            encoder.setTexture(inputTextureOne, index: 0)
            encoder.setTexture(inputTextureTwo, index: 1)
            encoder.setTexture(outputTexture, index: 2)
            encoder.setBytes(&averageBrightness, length: MemoryLayout<Float>.stride, index: 0)
            let gridSize = MTLSize(width: inputTextureOne.width, height: inputTextureOne.height, depth: 1)
            let threadGroupWidth = pipelineState.threadExecutionWidth
            let threadGroupHeight = pipelineState.maxTotalThreadsPerThreadgroup / threadGroupWidth
            let threadGroupSize = MTLSize(width: threadGroupWidth, height: threadGroupHeight, depth: 1)

            encoder.setComputePipelineState(pipelineState)
            if deviceSupportsNonuniformThreadgroups {
                encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
            } else {
                let threadGroupCount = MTLSize(width: (gridSize.width + threadGroupSize.width - 1) / threadGroupSize.width,
                                               height: (gridSize.height + threadGroupSize.height - 1) / threadGroupSize.height,
                                               depth: 1)
                encoder.dispatchThreadgroups(threadGroupCount, threadsPerThreadgroup: threadGroupSize)
            }
            encoder.endEncoding()

            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            return try textureManager.cgImage(texture: outputTexture)
        }
    }

    final class RecoverMissingPixelsKernel {
        private let textureManager: TextureManager
        private let inputTextureOne: MTLTexture
        private let inputTextureTwo: MTLTexture
        private let outputTexture: MTLTexture
        private var averageBrightness: Float

        private var commandQueue: MTLCommandQueue
        private let pipelineState: MTLComputePipelineState
        private var deviceSupportsNonuniformThreadgroups: Bool

        init(cgImageOne: CGImage, cgImageTwo: CGImage, averageBrightness: Float, library: MTLLibrary, textureManager: TextureManager) throws {
            guard let commandQueue = library.device.makeCommandQueue() else {
                throw MetalErrors.commandQueueCreationFailed
            }
            self.commandQueue = commandQueue
            deviceSupportsNonuniformThreadgroups = library.device.supportsFamily(.apple5)
            let constantValues = MTLFunctionConstantValues()

            constantValues.setConstantValue(&deviceSupportsNonuniformThreadgroups, type: .bool, index: 0)
            let function = try library.makeFunction(name: "add_missing_pixels", constantValues: constantValues)
            pipelineState = try library.device.makeComputePipelineState(function: function)
            self.textureManager = textureManager
            let inputTextureOne = try textureManager.texture(cgImage: cgImageOne)
            let inputTextureTwo = try textureManager.texture(cgImage: cgImageTwo)
            self.inputTextureOne = inputTextureOne
            self.inputTextureTwo = inputTextureTwo
            outputTexture = try textureManager.createMatchingTexture(texture: inputTextureOne)
            self.averageBrightness = averageBrightness
        }

        func applyKernel() throws -> CGImage {
            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                throw MetalErrors.commandBufferCreationFailed
            }

            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                throw MetalErrors.encoderCreationFailed
            }
            encoder.setTexture(inputTextureOne, index: 0)
            encoder.setTexture(inputTextureTwo, index: 1)
            encoder.setTexture(outputTexture, index: 2)
            encoder.setBytes(&averageBrightness, length: MemoryLayout<Float>.stride, index: 0)

            let gridSize = MTLSize(width: inputTextureOne.width, height: inputTextureOne.height, depth: 1)
            let threadGroupWidth = pipelineState.threadExecutionWidth
            let threadGroupHeight = pipelineState.maxTotalThreadsPerThreadgroup / threadGroupWidth
            let threadGroupSize = MTLSize(width: threadGroupWidth, height: threadGroupHeight, depth: 1)

            encoder.setComputePipelineState(pipelineState)

            if deviceSupportsNonuniformThreadgroups {
                encoder.dispatchThreads(gridSize,
                                        threadsPerThreadgroup: threadGroupSize)
            } else {
                let threadGroupCount = MTLSize(width: (gridSize.width + threadGroupSize.width - 1) / threadGroupSize.width,
                                               height: (gridSize.height + threadGroupSize.height - 1) / threadGroupSize.height,
                                               depth: 1)
                encoder.dispatchThreadgroups(threadGroupCount,
                                             threadsPerThreadgroup: threadGroupSize)
            }

            encoder.setComputePipelineState(pipelineState)
            encoder.endEncoding()

            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            return try textureManager.cgImage(texture: outputTexture)
        }
    }
}

private enum MetalErrors: Error {
    case deviceCreationFailed
    case encoderCreationFailed
    case commandQueueCreationFailed
    case commandBufferCreationFailed
    case kernelFailed
}

extension CGImage {
    var averageColor: UIColor? {
        let inputImage = CIImage(cgImage: self)
        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        return UIColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255, blue: CGFloat(bitmap[2]) / 255, alpha: CGFloat(bitmap[3]) / 255)
    }
}
