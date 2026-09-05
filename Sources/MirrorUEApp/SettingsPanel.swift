import AppKit
import ControlKit

/// In-app settings for OmniMirror.
final class SettingsPanel: NSView {
    var onClose: (() -> Void)?
    var onApply: (() -> Void)?

    private let effect = NSVisualEffectView()
    private let transportPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let fpsPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let kbPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let landPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private var touchesCheck: NSButton!

    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.50).cgColor

        effect.material = .hudWindow
        effect.blendingMode = .withinWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 18
        effect.layer?.cornerCurve = .continuous
        effect.layer?.masksToBounds = true
        effect.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effect)

        let title = NSTextField(labelWithString: "OmniMirror Settings")
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.alignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false

        let form = NSStackView()
        form.orientation = .vertical
        form.alignment = .leading
        form.spacing = 14
        form.translatesAutoresizingMaskIntoConstraints = false

        form.addArrangedSubview(labeled("Modalità connessione", control: transportPopup))
        form.addArrangedSubview(labeled("Frame rate", control: fpsPopup))
        form.addArrangedSubview(labeled("iPhone keyboard", control: kbPopup))
        form.addArrangedSubview(labeled("Landscape touch", control: landPopup))

        let touches = NSButton(checkboxWithTitle: "Show touches", target: self, action: #selector(touchesToggled(_:)))
        touches.state = MirrorUESettings.showTouches ? .on : .off
        touches.translatesAutoresizingMaskIntoConstraints = false
        self.touchesCheck = touches
        form.addArrangedSubview(touches)

        for mode in MirrorUESettings.TransportMode.allCases {
            transportPopup.addItem(withTitle: mode.title)
            transportPopup.lastItem?.representedObject = mode.rawValue
        }
        for mode in MirrorUESettings.FrameRate.allCases {
            fpsPopup.addItem(withTitle: mode.title)
            fpsPopup.lastItem?.representedObject = mode.rawValue
        }
        for mode in MirrorUESettings.KeyboardMode.allCases {
            kbPopup.addItem(withTitle: mode.title)
            kbPopup.lastItem?.representedObject = mode.rawValue
        }
        for mode in MirrorUESettings.LandscapeHome.allCases {
            landPopup.addItem(withTitle: mode.title)
            landPopup.lastItem?.representedObject = mode.rawValue
        }

        select(transportPopup, value: MirrorUESettings.transportMode.rawValue)
        select(fpsPopup, value: MirrorUESettings.frameRate.rawValue)
        select(kbPopup, value: MirrorUESettings.keyboardMode.rawValue)
        select(landPopup, value: MirrorUESettings.landscapeHome.rawValue)

        let done = NSButton(title: "Done", target: self, action: #selector(doneClicked))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"
        done.translatesAutoresizingMaskIntoConstraints = false

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelClicked))
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"
        cancel.translatesAutoresizingMaskIntoConstraints = false

        let buttons = NSStackView(views: [cancel, done])
        buttons.orientation = .horizontal
        buttons.spacing = 12
        buttons.translatesAutoresizingMaskIntoConstraints = false

        effect.addSubview(title)
        effect.addSubview(form)
        effect.addSubview(buttons)

        let preferredWidth = effect.widthAnchor.constraint(equalToConstant: 380)
        preferredWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            effect.centerXAnchor.constraint(equalTo: centerXAnchor),
            effect.centerYAnchor.constraint(equalTo: centerYAnchor),
            preferredWidth,
            effect.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -16),

            title.topAnchor.constraint(equalTo: effect.topAnchor, constant: 22),
            title.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 20),
            title.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -20),

            form.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 18),
            form.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 26),
            form.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -26),

            buttons.topAnchor.constraint(equalTo: form.bottomAnchor, constant: 22),
            buttons.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -26),
            buttons.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -20),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if !effect.frame.contains(p) {
            onClose?()
        }
    }

    private func labeled(_ title: String, control: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabelColor
        control.translatesAutoresizingMaskIntoConstraints = false
        control.widthAnchor.constraint(equalToConstant: 220).isActive = true
        let col = NSStackView(views: [label, control])
        col.orientation = .vertical
        col.alignment = .leading
        col.spacing = 4
        return col
    }

    private func select(_ popup: NSPopUpButton, value: Any) {
        for (i, item) in (popup.itemArray).enumerated() {
            if let rep = item.representedObject as? Int, let v = value as? Int, rep == v {
                popup.selectItem(at: i)
                return
            }
            if let rep = item.representedObject as? String, let v = value as? String, rep == v {
                popup.selectItem(at: i)
                return
            }
        }
    }

    @objc private func touchesToggled(_ sender: NSButton) {
        MirrorUESettings.showTouches = (sender.state == .on)
    }

    @objc private func doneClicked() {
        if let raw = transportPopup.selectedItem?.representedObject as? String,
           let mode = MirrorUESettings.TransportMode(rawValue: raw) {
            MirrorUESettings.transportMode = mode
        }
        if let raw = fpsPopup.selectedItem?.representedObject as? Int,
           let mode = MirrorUESettings.FrameRate(rawValue: raw) {
            MirrorUESettings.frameRate = mode
        }
        if let raw = kbPopup.selectedItem?.representedObject as? String,
           let mode = MirrorUESettings.KeyboardMode(rawValue: raw) {
            MirrorUESettings.keyboardMode = mode
        }
        if let raw = landPopup.selectedItem?.representedObject as? String,
           let mode = MirrorUESettings.LandscapeHome(rawValue: raw) {
            MirrorUESettings.landscapeHome = mode
        }
        MirrorUESettings.showTouches = (touchesCheck.state == .on)
        MirrorUESettings.applyToEnvironment()
        onApply?()
        onClose?()
    }

    @objc private func cancelClicked() {
        onClose?()
    }
}
