import AppKit

func sendMediaKey(_ key: Int) {
    let keyDown = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: .init(rawValue: 0xa00), timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: (key << 16) | (0xa << 8), data2: -1)
    let keyUp = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: .init(rawValue: 0xb00), timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: (key << 16) | (0xb << 8), data2: -1)
    keyDown?.cgEvent?.post(tap: .cghidEventTap)
    keyUp?.cgEvent?.post(tap: .cghidEventTap)
}
