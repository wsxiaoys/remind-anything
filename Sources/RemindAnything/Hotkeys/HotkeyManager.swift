import AppKit
import Carbon.HIToolbox

/// A global hotkey definition (Carbon key code + Carbon modifier mask).
struct Hotkey: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32   // Carbon modifiers: cmdKey / optionKey / shiftKey / controlKey

    var displayString: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey)  != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey)   != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey)     != 0 { s += "⌘" }
        s += Hotkey.keyName(for: keyCode)
        return s
    }

    static func keyName(for keyCode: UInt32) -> String {
        let map: [UInt32: String] = [
            18: "1", 19: "2", 20: "3", 21: "4", 23: "5",
            22: "6", 26: "7", 28: "8", 25: "9", 29: "0"
        ]
        return map[keyCode] ?? "Key\(keyCode)"
    }

    // Sensible defaults matching the design doc.
    static let defaultWindow = Hotkey(keyCode: 18, modifiers: UInt32(optionKey | shiftKey)) // ⌥⇧1
    static let defaultRegion = Hotkey(keyCode: 19, modifiers: UInt32(optionKey | shiftKey)) // ⌥⇧2
    static let defaultScreen = Hotkey(keyCode: 20, modifiers: UInt32(optionKey | shiftKey)) // ⌥⇧3
}

/// Registers system-wide hotkeys via Carbon and dispatches to handlers.
@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var handlers: [UInt32: () -> Void] = [:]
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private var nextID: UInt32 = 1

    private let signature: OSType = {
        // 'RmAn'
        let chars: [UInt8] = Array("RmAn".utf8)
        return (OSType(chars[0]) << 24) | (OSType(chars[1]) << 16) | (OSType(chars[2]) << 8) | OSType(chars[3])
    }()

    private init() {}

    /// Install the shared Carbon event handler (idempotent).
    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, eventRef, _ in
            var hkID = EventHotKeyID()
            let status = GetEventParameter(eventRef,
                                           EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID),
                                           nil,
                                           MemoryLayout<EventHotKeyID>.size,
                                           nil,
                                           &hkID)
            if status == noErr {
                let id = hkID.id
                Task { @MainActor in
                    HotkeyManager.shared.fire(id: id)
                }
            }
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(),
                            callback,
                            1,
                            &eventType,
                            nil,
                            &eventHandler)
    }

    fileprivate func fire(id: UInt32) {
        handlers[id]?()
    }

    /// Register a hotkey; returns the internal id (also used to unregister).
    @discardableResult
    func register(_ hotkey: Hotkey, handler: @escaping () -> Void) -> UInt32 {
        installEventHandlerIfNeeded()
        let id = nextID
        nextID += 1

        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(hotkey.keyCode,
                                         hotkey.modifiers,
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &ref)
        if status == noErr, let ref {
            hotKeyRefs[id] = ref
            handlers[id] = handler
        } else {
            NSLog("RemindAnything: failed to register hotkey \(hotkey.displayString) (status \(status))")
        }
        return id
    }

    func unregister(id: UInt32) {
        if let ref = hotKeyRefs[id] {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs[id] = nil
        handlers[id] = nil
    }

    func unregisterAll() {
        for id in Array(hotKeyRefs.keys) { unregister(id: id) }
    }
}
