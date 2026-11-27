import Foundation

enum PropertyList {
    static func data(from dictionary: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: dictionary, format: .xml, options: 0)
    }

    static func dictionary(from data: Data) throws -> [String: Any] {
        guard let dictionary = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw UsbmuxError.malformedReply
        }
        return dictionary
    }
}
