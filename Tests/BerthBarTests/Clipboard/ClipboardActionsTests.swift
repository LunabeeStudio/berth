import BerthCore
import Testing

@testable import BerthBar

@MainActor
@Suite
struct ClipboardActionsTests {
    @Test
    func `a copy puts the text on the pasteboard and shows the serial`() async {
        let clipboard: FakeDeviceClipboard = .init(.success("hello"))
        let pasteboard: FakeMacPasteboard = .init(content: "before")
        let actions: ClipboardActions = .init(clipboard: clipboard, pasteboard: pasteboard)

        await actions.copy(serial: "emulator-5554").value

        #expect(clipboard.requestedSerials == ["emulator-5554"])
        #expect(pasteboard.content == "hello")
        #expect(actions.caption == "Copied clipboard of emulator-5554")
    }

    @Test
    func `accents, emoji and newlines reach the pasteboard unchanged`() async {
        let text: String = "Café déjà vu\nligne deux 🎉👩‍👩‍👧\r\n日本語 end\n"
        let pasteboard: FakeMacPasteboard = .init()
        let actions: ClipboardActions = .init(clipboard: FakeDeviceClipboard(.success(text)), pasteboard: pasteboard)

        await actions.copy(serial: "R3CT312YV5B").value

        #expect(pasteboard.content == text)
    }

    @Test(arguments: [nil, ""] as [String?])
    func `an empty clipboard keeps the pasteboard and says so`(empty: String?) async {
        let pasteboard: FakeMacPasteboard = .init(content: "keep me")
        let actions: ClipboardActions = .init(clipboard: FakeDeviceClipboard(.success(empty)), pasteboard: pasteboard)

        await actions.copy(serial: "R3CT312YV5B").value

        #expect(pasteboard.content == "keep me")
        #expect(pasteboard.writes == 0)
        #expect(actions.caption == "R3CT312YV5B: clipboard empty")
    }

    @Test
    func `a missing scrcpy shows the mirror message and keeps the pasteboard`() async {
        let pasteboard: FakeMacPasteboard = .init(content: "keep me")
        let actions: ClipboardActions = .init(clipboard: FakeDeviceClipboard(.failure(.scrcpyNotFound)), pasteboard: pasteboard)

        await actions.copy(serial: "emulator-5554").value

        #expect(actions.caption == ScrcpyMirror.notFoundMessage)
        #expect(pasteboard.writes == 0)
    }

    @Test
    func `a timeout and an adb failure show their own line`() async {
        let clipboard: FakeDeviceClipboard = .init(.failure(.timedOut(serial: "emulator-5554")))
        let actions: ClipboardActions = .init(clipboard: clipboard, pasteboard: FakeMacPasteboard())

        await actions.copy(serial: "emulator-5554").value
        #expect(actions.caption == "emulator-5554: clipboard read timed out")

        clipboard.update(.failure(.failed(line: "error: device 'x' not found")))
        await actions.copy(serial: "x").value
        #expect(actions.caption == "error: device 'x' not found")
    }

    @Test
    func `a click shows that the read is running and the result replaces it`() async {
        let clipboard: GatedDeviceClipboard = .init(text: "hello")
        let actions: ClipboardActions = .init(clipboard: clipboard, pasteboard: FakeMacPasteboard())

        let task: Task<Void, Never> = actions.copy(serial: "emulator-5554")
        #expect(actions.caption == "Reading clipboard of emulator-5554…")

        clipboard.open()
        await task.value

        #expect(actions.caption == "Copied clipboard of emulator-5554")
    }

    @Test
    func `a click on a serial that is still being read starts no second read`() async {
        let clipboard: GatedDeviceClipboard = .init(text: "hello")
        let pasteboard: FakeMacPasteboard = .init()
        let actions: ClipboardActions = .init(clipboard: clipboard, pasteboard: pasteboard)

        let first: Task<Void, Never> = actions.copy(serial: "emulator-5554")
        let second: Task<Void, Never> = actions.copy(serial: "emulator-5554")
        clipboard.open()
        await first.value
        await second.value

        #expect(clipboard.requestedSerials == ["emulator-5554"])
        #expect(pasteboard.writes == 1)
    }

    @Test
    func `once a read ended the same serial can be read again`() async {
        let clipboard: FakeDeviceClipboard = .init(.success("hello"))
        let actions: ClipboardActions = .init(clipboard: clipboard, pasteboard: FakeMacPasteboard())

        await actions.copy(serial: "emulator-5554").value
        await actions.copy(serial: "emulator-5554").value

        #expect(clipboard.requestedSerials == ["emulator-5554", "emulator-5554"])
    }

    @Test
    func `the next click replaces the previous caption`() async {
        let clipboard: FakeDeviceClipboard = .init(.success(nil))
        let actions: ClipboardActions = .init(clipboard: clipboard, pasteboard: FakeMacPasteboard())
        await actions.copy(serial: "a").value
        #expect(actions.caption == "a: clipboard empty")

        let task: Task<Void, Never> = actions.copy(serial: "b")
        #expect(actions.caption == "Reading clipboard of b…")
        await task.value

        #expect(actions.caption == "b: clipboard empty")
    }
}
