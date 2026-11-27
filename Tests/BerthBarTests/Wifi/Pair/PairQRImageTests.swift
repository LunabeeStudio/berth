import CoreImage
import Testing

@testable import BerthBar

@Suite
struct PairQRImageTests {
    @Test
    func `the image decodes back to the payload`() throws {
        let payload: String = PairQR(name: "berth-ab12cd34", password: "s3cretpass99").payload
        let image: CGImage = try #require(PairQRImage.make(payload: payload))
        let detector: CIDetector = try #require(CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]))

        let messages: [String?] = detector.features(in: CIImage(cgImage: image)).compactMap { ($0 as? CIQRCodeFeature)?.messageString }

        #expect(messages == [payload])
    }

    @Test
    func `the modules are whole pixels with a quiet zone`() throws {
        let small: CGImage = try #require(PairQRImage.make(payload: "WIFI:T:ADB;S:a;P:b;;", moduleSize: 4, quietZoneModules: 4))
        let large: CGImage = try #require(PairQRImage.make(payload: "WIFI:T:ADB;S:a;P:b;;", moduleSize: 8, quietZoneModules: 4))

        #expect(small.width == small.height)
        #expect(small.width % 4 == 0)
        #expect(large.width == small.width * 2)
    }
}
