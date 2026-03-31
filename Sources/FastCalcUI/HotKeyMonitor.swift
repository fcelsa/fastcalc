import Carbon.HIToolbox
import Foundation

public final class HotKeyMonitor {
    private let hotKeyIdentifier: UInt32 = 1
    private let hotKeySignature = OSType(0x6663746B)

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var callback: (@MainActor () -> Void)?

    public init() {}

    deinit {
        unregister()
    }

    @discardableResult
    public func registerF16(_ callback: @escaping @MainActor () -> Void) -> Bool {
        unregister()
        self.callback = callback

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData else { return noErr }
                let monitor = Unmanaged<HotKeyMonitor>.fromOpaque(userData).takeUnretainedValue()

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

                guard status == noErr else { return noErr }
                if hotKeyID.id == monitor.hotKeyIdentifier {
                    let callback = monitor.callback
                    Task { @MainActor in
                        callback?()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &handlerRef
        )
        guard handlerStatus == noErr else {
            self.callback = nil
            return false
        }

        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: hotKeyIdentifier)
        let hotKeyStatus = RegisterEventHotKey(
            UInt32(kVK_F16),
            UInt32(0),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard hotKeyStatus == noErr else {
            unregister()
            return false
        }

        return true
    }

    public func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }

        callback = nil
    }
}
