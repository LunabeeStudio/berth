import Foundation

protocol UsbmuxConnection {
    func send(_ data: Data) throws
    func receive(count: Int) throws -> Data
}
