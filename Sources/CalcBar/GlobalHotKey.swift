import Carbon
import Foundation

nonisolated(unsafe) private var hotKeyHandlers: [UInt32: () -> Void] = [:]
nonisolated(unsafe) private var nextHotKeyID: UInt32 = 1
nonisolated(unsafe) private var hotKeyEventHandlerInstalled = false

struct HotKeyModifiers: OptionSet {
    let rawValue: UInt32

    static let control = HotKeyModifiers(rawValue: UInt32(controlKey))
    static let option = HotKeyModifiers(rawValue: UInt32(optionKey))
    static let command = HotKeyModifiers(rawValue: UInt32(cmdKey))
    static let shift = HotKeyModifiers(rawValue: UInt32(shiftKey))
}

final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private let id: UInt32

    init?(keyCode: UInt32, modifiers: HotKeyModifiers, handler: @escaping () -> Void) {
        Self.installEventHandlerIfNeeded()

        id = nextHotKeyID
        nextHotKeyID += 1
        hotKeyHandlers[id] = handler

        let hotKeyID = EventHotKeyID(signature: FourCharCode("CBAR"), id: id)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers.rawValue,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr else {
            hotKeyHandlers[id] = nil
            return nil
        }
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyHandlers[id] = nil
    }

    private static func installEventHandlerIfNeeded() {
        guard !hotKeyEventHandlerInstalled else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(GetApplicationEventTarget(), hotKeyEventHandler, 1, &eventType, nil, nil)

        hotKeyEventHandlerInstalled = true
    }
}

private func hotKeyEventHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    if status == noErr {
        hotKeyHandlers[hotKeyID.id]?()
    }

    return noErr
}

private extension FourCharCode {
    init(_ string: String) {
        var result: UInt32 = 0
        for scalar in string.unicodeScalars.prefix(4) {
            result = (result << 8) + scalar.value
        }
        self = result
    }
}
