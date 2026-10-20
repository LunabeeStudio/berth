import Foundation

public enum DeviceHubURL {
    private static let scheme: String = "devices"

    public static func open(udid: String) -> URL? {
        var components: URLComponents = .init()
        components.scheme = scheme
        components.host = "device"
        components.path = "/open"
        components.queryItems = [.init(name: "id", value: udid)]
        return components.url
    }
}
