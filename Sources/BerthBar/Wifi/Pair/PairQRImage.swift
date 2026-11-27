import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

enum PairQRImage {
    static func make(payload: String, moduleSize: Int = 8, quietZoneModules: Int = 4) -> CGImage? {
        let generator: CIFilter & CIQRCodeGenerator = CIFilter.qrCodeGenerator()
        generator.message = Data(payload.utf8)
        generator.correctionLevel = "M"
        guard let code = generator.outputImage else { return nil }
        let scale: CGFloat = .init(moduleSize)
        let modules: CIImage = code.samplingNearest().transformed(by: .init(scaleX: scale, y: scale))
        let canvas: CGRect = modules.extent.insetBy(dx: -scale * CGFloat(quietZoneModules), dy: -scale * CGFloat(quietZoneModules))
        let background: CIImage = .init(color: .white).cropped(to: canvas)
        return CIContext().createCGImage(modules.composited(over: background), from: canvas)
    }
}
