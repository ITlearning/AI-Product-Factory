import MetalKit

/// 꽃잎·낙엽(사진 잎 아틀라스, 절차 꽃잎)과 서리 덧그림. 텍스처는 앱 타깃에만 있다 — 없으면 nil 이라 예전 입자를 그린다.
final class SkyOverlayGPU {
    static let shared: SkyOverlayGPU? = SkyGPU.shared.flatMap { try? SkyOverlayGPU(gpu: $0) }

    /// 잎 아틀라스 4×2 칸 — SkyFlakes.metal 이 칸 번호로 읽는다.
    static let leafCells = 8

    let leaf: MTLRenderPipelineState
    let frost: MTLRenderPipelineState
    let leafColor: MTLTexture
    let leafNormal: MTLTexture
    let frostCrystals: MTLTexture

    init(gpu: SkyGPU) throws {
        let device = gpu.device
        let bundle = Bundle(for: SharedBundleMarker.self)
        let loader = MTKTextureLoader(device: device)
        func load(_ name: String, _ ext: String, srgb: Bool) throws -> MTLTexture {
            guard let url = bundle.url(forResource: name, withExtension: ext) else { throw CocoaError(.fileNoSuchFile) }
            return try loader.newTexture(URL: url, options: [.SRGB: srgb, .generateMipmaps: true,
                                                             .textureStorageMode: MTLStorageMode.private.rawValue])
        }
        leafColor = try load("SkyLeaves", "jpg", srgb: true)
        leafNormal = try load("SkyLeavesNormal", "jpg", srgb: false)
        frostCrystals = try load("SkyFrost", "jpg", srgb: false)
        let lib = try device.makeDefaultLibrary(bundle: bundle)
        func pipeline(_ vertex: String, _ fragment: String) throws -> MTLRenderPipelineState {
            guard let v = lib.makeFunction(name: vertex), let f = lib.makeFunction(name: fragment) else {
                throw CocoaError(.featureUnsupported)
            }
            let d = MTLRenderPipelineDescriptor()
            d.vertexFunction = v
            d.fragmentFunction = f
            let a = d.colorAttachments[0]!
            a.pixelFormat = SkyGPU.format
            a.isBlendingEnabled = true
            a.rgbBlendOperation = .add
            a.alphaBlendOperation = .add
            a.sourceRGBBlendFactor = .one
            a.destinationRGBBlendFactor = .oneMinusSourceAlpha
            a.sourceAlphaBlendFactor = .zero
            a.destinationAlphaBlendFactor = .one
            return try device.makeRenderPipelineState(descriptor: d)
        }
        leaf = try pipeline("skyLeafVertex", "skyLeafFragment")
        frost = try pipeline("skyFullscreen", "skyFrostOverlay")
    }

    func drawsFlakes(_ scene: SkyScene) -> Bool { scene == .petals || scene == .leaves }

    func drawFlakes(_ e: MTLRenderCommandEncoder, uniforms floats: [SIMD4<Float>], count: Int) {
        let bytes = MemoryLayout<SIMD4<Float>>.stride * floats.count
        e.setRenderPipelineState(leaf)
        floats.withUnsafeBytes {
            e.setVertexBytes($0.baseAddress!, length: bytes, index: 0)
            e.setFragmentBytes($0.baseAddress!, length: bytes, index: 0)
        }
        e.setFragmentTexture(leafColor, index: 0)
        e.setFragmentTexture(leafNormal, index: 1)
        e.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: count)
    }

    func drawFrost(_ e: MTLRenderCommandEncoder, uniforms floats: [SIMD4<Float>]) {
        let bytes = MemoryLayout<SIMD4<Float>>.stride * floats.count
        e.setRenderPipelineState(frost)
        floats.withUnsafeBytes { e.setFragmentBytes($0.baseAddress!, length: bytes, index: 0) }
        e.setFragmentTexture(frostCrystals, index: 0)
        e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }
}
