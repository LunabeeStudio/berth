import BerthCore
import NIOCore
import NIOPosix

final class AcceptErrorFilter: ChannelInboundHandler {
    typealias InboundIn = Channel

    private static let logInterval: TimeAmount = .seconds(1)

    private var nextLog: NIODeadline = .now()
    private var suppressed: Int = 0

    func errorCaught(context: ChannelHandlerContext, error: any Error) {
        guard error is NIOFcntlFailedError else {
            context.fireErrorCaught(error)
            return
        }
        guard NIODeadline.now() >= nextLog else {
            suppressed += 1
            return
        }
        let more: String = suppressed > 0 ? " (\(suppressed) more since the last line)" : ""
        Log.info("accept failed: \(error)\(more)")
        suppressed = 0
        nextLog = .now() + Self.logInterval
    }
}
