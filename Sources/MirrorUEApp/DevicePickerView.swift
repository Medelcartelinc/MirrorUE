import AppKit
import ControlKit
import DeviceKit

/// Startup panel: list USB or Wi-Fi iPhones and let the user pick one.
final class DevicePickerView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    var onSelect: ((DeviceInfo) -> Void)?

    private let effect = NSVisualEffectView()
    private let titleIcon = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "Connessione iPhone")
    private let hintLabel = NSTextField(wrappingLabelWithString:
        "Scegli la modalità di connessione e seleziona il tuo iPhone per avviare il mirroring.")
    private let transportSegment = NSSegmentedControl()

    private let noticeBox = NSView()
    private let noticeIcon = NSImageView()
    private let noticeLabel = NSTextField(wrappingLabelWithString: "")
    private let noticeActionButton = NSButton()

    private let scroll = NSScrollView()
    private let table = NSTableView()
    private let refreshButton = NSButton()
    private let connectButton = NSButton()
    private let emptyLabel = NSTextField(wrappingLabelWithString:
        "Nessun iPhone trovato — collega il cavo USB o assicurati che l'iPhone sia sulla stessa rete Wi-Fi.")

    private var devices: [DeviceInfo] = []
    private var allDetectedDevices: [DeviceInfo] = []
    private var pollTimer: Timer?
    private var noticeHeightConstraint: NSLayoutConstraint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor

        effect.material = .hudWindow
        effect.blendingMode = .withinWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 20
        effect.layer?.cornerCurve = .continuous
        effect.layer?.masksToBounds = true
        effect.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effect)

        let rim = NSView()
        rim.wantsLayer = true
        rim.layer?.cornerRadius = 20
        rim.layer?.cornerCurve = .continuous
        rim.layer?.borderWidth = 0.5
        rim.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        rim.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.04).cgColor
        rim.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(rim)

        titleIcon.image = sfSymbol("iphone.gen3", size: 22)
        titleIcon.contentTintColor = .labelColor
        titleIcon.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let titleRow = NSStackView(views: [titleIcon, titleLabel])
        titleRow.orientation = .horizontal
        titleRow.spacing = 8
        titleRow.alignment = .centerY
        titleRow.translatesAutoresizingMaskIntoConstraints = false

        hintLabel.font = .systemFont(ofSize: 12, weight: .regular)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.alignment = .center
        hintLabel.lineBreakMode = .byWordWrapping
        hintLabel.maximumNumberOfLines = 0
        hintLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        // Transport segmented control
        transportSegment.segmentCount = 3
        transportSegment.setLabel("⚡ Cavo USB", forSegment: 0)
        transportSegment.setLabel("📶 Wi-Fi", forSegment: 1)
        transportSegment.setLabel("🔄 Tutti", forSegment: 2)
        transportSegment.setToolTip("Latenza ultra-bassa (0–3 ms) via cavo USB", forSegment: 0)
        transportSegment.setToolTip("Connessione senza fili su rete locale", forSegment: 1)
        transportSegment.setToolTip("Mostra tutti i dispositivi USB e Wi-Fi", forSegment: 2)
        transportSegment.segmentStyle = .texturedRounded
        transportSegment.trackingMode = .selectOne
        switch MirrorUESettings.transportMode {
        case .usb:
            transportSegment.selectedSegment = 0
        case .wifi:
            transportSegment.selectedSegment = 1
        case .auto:
            transportSegment.selectedSegment = 0
        }
        transportSegment.target = self
        transportSegment.action = #selector(transportSegmentChanged(_:))
        transportSegment.translatesAutoresizingMaskIntoConstraints = false

        // Notice Box (shown if USB is selected but only Wi-Fi iPhone is present)
        noticeBox.wantsLayer = true
        noticeBox.layer?.cornerRadius = 10
        noticeBox.layer?.cornerCurve = .continuous
        noticeBox.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.12).cgColor
        noticeBox.layer?.borderWidth = 1
        noticeBox.layer?.borderColor = NSColor.systemOrange.withAlphaComponent(0.35).cgColor
        noticeBox.isHidden = true
        noticeBox.translatesAutoresizingMaskIntoConstraints = false

        noticeIcon.image = sfSymbol("exclamationmark.triangle.fill", size: 16)
        noticeIcon.contentTintColor = .systemOrange
        noticeIcon.translatesAutoresizingMaskIntoConstraints = false

        noticeLabel.font = .systemFont(ofSize: 11, weight: .medium)
        noticeLabel.textColor = .labelColor
        noticeLabel.lineBreakMode = .byWordWrapping
        noticeLabel.maximumNumberOfLines = 0
        noticeLabel.translatesAutoresizingMaskIntoConstraints = false

        noticeActionButton.title = "Usa Wi-Fi"
        noticeActionButton.image = sfSymbol("wifi", size: 12)
        noticeActionButton.imagePosition = .imageLeading
        noticeActionButton.font = .systemFont(ofSize: 11, weight: .semibold)
        noticeActionButton.bezelStyle = .rounded
        noticeActionButton.target = self
        noticeActionButton.action = #selector(switchToWifiClicked)
        noticeActionButton.translatesAutoresizingMaskIntoConstraints = false

        noticeBox.addSubview(noticeIcon)
        noticeBox.addSubview(noticeLabel)
        noticeBox.addSubview(noticeActionButton)

        NSLayoutConstraint.activate([
            noticeIcon.leadingAnchor.constraint(equalTo: noticeBox.leadingAnchor, constant: 10),
            noticeIcon.topAnchor.constraint(equalTo: noticeBox.topAnchor, constant: 10),
            noticeIcon.widthAnchor.constraint(equalToConstant: 18),
            noticeIcon.heightAnchor.constraint(equalToConstant: 18),

            noticeLabel.leadingAnchor.constraint(equalTo: noticeIcon.trailingAnchor, constant: 8),
            noticeLabel.topAnchor.constraint(equalTo: noticeBox.topAnchor, constant: 8),
            noticeLabel.bottomAnchor.constraint(equalTo: noticeBox.bottomAnchor, constant: -8),
            noticeLabel.trailingAnchor.constraint(equalTo: noticeActionButton.leadingAnchor, constant: -8),

            noticeActionButton.trailingAnchor.constraint(equalTo: noticeBox.trailingAnchor, constant: -10),
            noticeActionButton.centerYAnchor.constraint(equalTo: noticeBox.centerYAnchor),
            noticeActionButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
        ])

        emptyLabel.font = .systemFont(ofSize: 12, weight: .medium)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.lineBreakMode = .byWordWrapping
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        table.style = .plain
        table.headerView = nil
        table.rowHeight = 60
        table.intercellSpacing = NSSize(width: 0, height: 6)
        table.backgroundColor = .clear
        table.selectionHighlightStyle = .regular
        table.doubleAction = #selector(connectClicked)
        table.target = self
        table.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("device"))
        col.resizingMask = .autoresizingMask
        col.minWidth = 200
        table.addTableColumn(col)
        table.dataSource = self
        table.delegate = self

        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        styleButton(
            refreshButton, title: "Aggiorna", symbolName: "arrow.clockwise", primary: false,
            tip: "Cerca di nuovo i dispositivi collegati in USB o Wi-Fi")
        refreshButton.target = self
        refreshButton.action = #selector(reload)

        styleButton(
            connectButton, title: "Connetti", symbolName: "bolt.fill", primary: true,
            tip: "Avvia il mirroring e il controllo dell'iPhone selezionato")
        connectButton.keyEquivalent = "\r"
        connectButton.target = self
        connectButton.action = #selector(connectClicked)

        let buttons = NSStackView(views: [refreshButton, connectButton])
        buttons.orientation = .horizontal
        buttons.spacing = 10
        buttons.distribution = .fillEqually
        buttons.translatesAutoresizingMaskIntoConstraints = false

        effect.addSubview(titleRow)
        effect.addSubview(hintLabel)
        effect.addSubview(transportSegment)
        effect.addSubview(noticeBox)
        effect.addSubview(scroll)
        effect.addSubview(emptyLabel)
        effect.addSubview(buttons)

        let panelW = effect.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.9)
        panelW.priority = .defaultHigh
        let panelH = effect.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.82)
        panelH.priority = .defaultHigh

        let noticeHeight = noticeBox.heightAnchor.constraint(equalToConstant: 58)
        noticeHeightConstraint = noticeHeight

        NSLayoutConstraint.activate([
            effect.centerXAnchor.constraint(equalTo: centerXAnchor),
            effect.centerYAnchor.constraint(equalTo: centerYAnchor),
            effect.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 12),
            effect.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            effect.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 12),
            effect.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12),
            panelW,
            effect.widthAnchor.constraint(lessThanOrEqualToConstant: 540),
            effect.widthAnchor.constraint(greaterThanOrEqualToConstant: 320),
            panelH,
            effect.heightAnchor.constraint(lessThanOrEqualToConstant: 480),
            effect.heightAnchor.constraint(greaterThanOrEqualToConstant: 340),

            rim.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            rim.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            rim.topAnchor.constraint(equalTo: effect.topAnchor),
            rim.bottomAnchor.constraint(equalTo: effect.bottomAnchor),

            titleRow.topAnchor.constraint(equalTo: effect.topAnchor, constant: 18),
            titleRow.centerXAnchor.constraint(equalTo: effect.centerXAnchor),

            hintLabel.topAnchor.constraint(equalTo: titleRow.bottomAnchor, constant: 8),
            hintLabel.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 20),
            hintLabel.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -20),

            transportSegment.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 12),
            transportSegment.centerXAnchor.constraint(equalTo: effect.centerXAnchor),
            transportSegment.heightAnchor.constraint(equalToConstant: 26),

            noticeBox.topAnchor.constraint(equalTo: transportSegment.bottomAnchor, constant: 10),
            noticeBox.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 14),
            noticeBox.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -14),
            noticeHeight,

            scroll.topAnchor.constraint(equalTo: noticeBox.isHidden ? transportSegment.bottomAnchor : noticeBox.bottomAnchor, constant: 10),
            scroll.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 14),
            scroll.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -14),
            scroll.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -12),

            emptyLabel.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 16),
            emptyLabel.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -16),
            emptyLabel.centerYAnchor.constraint(equalTo: scroll.centerYAnchor),

            buttons.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 16),
            buttons.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -16),
            buttons.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -16),
            buttons.heightAnchor.constraint(equalToConstant: 36),
        ])

        reload()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.reload()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    deinit { pollTimer?.invalidate() }

    override func layout() {
        super.layout()
        hintLabel.preferredMaxLayoutWidth = max(220, effect.bounds.width - 40)
        emptyLabel.preferredMaxLayoutWidth = max(200, effect.bounds.width - 56)
        noticeLabel.preferredMaxLayoutWidth = max(180, effect.bounds.width - 150)
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    @objc private func transportSegmentChanged(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            MirrorUESettings.transportMode = .usb
        case 1:
            MirrorUESettings.transportMode = .wifi
        default:
            MirrorUESettings.transportMode = .auto
        }
        reload()
    }

    @objc private func switchToWifiClicked() {
        transportSegment.selectedSegment = 1
        MirrorUESettings.transportMode = .wifi
        reload()
    }

    @objc func reload() {
        let previous = selectedDevice()?.udid
        let all = (try? Usbmux.listDevices()) ?? []
        allDetectedDevices = all

        let mode = transportSegment.selectedSegment
        switch mode {
        case 0: // USB
            devices = all.filter { $0.isUSB }
        case 1: // Wi-Fi
            devices = all.filter { $0.isNetwork }
        default: // Tutti
            // Prefer USB first, then Wi-Fi
            devices = all.sorted { $0.isUSB && !$1.isUSB }
        }

        // Diagnostics for USB
        if mode == 0 && devices.isEmpty {
            let hasWifi = all.contains(where: { $0.isNetwork })
            if hasWifi {
                noticeBox.isHidden = false
                noticeLabel.stringValue = "iPhone rilevato su rete Wi-Fi, ma non via cavo USB.\nPer latenza 0–3 ms: usa porta diretta Mac e tocca «Autorizza questo computer»."
                emptyLabel.stringValue = "Nessun dispositivo USB rilevato.\nUsa il pulsante «Usa Wi-Fi» sopra o ricollega il cavo."
            } else {
                noticeBox.isHidden = true
                emptyLabel.stringValue = "Nessun iPhone rilevato.\n1. Collega il cavo USB direttamente a una porta del Mac.\n2. Sblocca lo schermo dell'iPhone e tocca «Autorizza questo computer»."
            }
        } else if mode == 1 && devices.isEmpty {
            noticeBox.isHidden = true
            emptyLabel.stringValue = "Nessun iPhone rilevato sulla rete Wi-Fi.\nAssicurati che l'iPhone e il Mac siano sulla stessa rete locale."
        } else {
            noticeBox.isHidden = true
            emptyLabel.stringValue = "Nessun iPhone trovato."
        }

        table.reloadData()
        emptyLabel.isHidden = !devices.isEmpty
        connectButton.isEnabled = !devices.isEmpty
        connectButton.alphaValue = devices.isEmpty ? 0.45 : 1

        if devices.count == 1 {
            table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        } else if let previous, let idx = devices.firstIndex(where: { $0.udid == previous }) {
            table.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
        }
    }

    @objc private func connectClicked() {
        guard let device = selectedDevice() else { return }
        stopPolling()
        onSelect?(device)
    }

    private func selectedDevice() -> DeviceInfo? {
        let row = table.selectedRow
        guard row >= 0, row < devices.count else { return nil }
        return devices[row]
    }

    func numberOfRows(in tableView: NSTableView) -> Int { devices.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let device = devices[row]
        let cell = DeviceRowView()
        cell.configure(device: device)
        return cell
    }

    private func styleButton(_ button: NSButton, title: String, symbolName: String, primary: Bool, tip: String) {
        button.title = title
        button.image = sfSymbol(symbolName, size: primary ? 14 : 13)
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
        button.font = .systemFont(ofSize: 13, weight: primary ? .semibold : .medium)
        button.bezelStyle = .rounded
        button.isBordered = !primary
        button.toolTip = tip
        button.translatesAutoresizingMaskIntoConstraints = false
        if primary {
            button.contentTintColor = .white
            button.wantsLayer = true
            button.layer?.cornerRadius = 10
            button.layer?.cornerCurve = .continuous
            button.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        } else {
            button.contentTintColor = .labelColor
        }
    }

    private func sfSymbol(_ name: String, size: CGFloat) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: size, weight: .semibold))
    }
}

// MARK: - Device row

private final class DeviceRowView: NSView {
    private let icon = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let badgeContainer = NSView()
    private let badgeLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor

        icon.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        detailLabel.font = .systemFont(ofSize: 11, weight: .regular)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingMiddle
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        badgeContainer.wantsLayer = true
        badgeContainer.layer?.cornerRadius = 8
        badgeContainer.layer?.cornerCurve = .continuous
        badgeContainer.layer?.borderWidth = 1
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false

        badgeLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        badgeLabel.alignment = .center
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.addSubview(badgeLabel)

        addSubview(icon)
        addSubview(nameLabel)
        addSubview(detailLabel)
        addSubview(badgeContainer)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),

            badgeContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            badgeContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            badgeContainer.heightAnchor.constraint(equalToConstant: 24),

            badgeLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 8),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -8),
            badgeLabel.centerYAnchor.constraint(equalTo: badgeContainer.centerYAnchor),

            nameLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: badgeContainer.leadingAnchor, constant: -8),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 11),

            detailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: badgeContainer.leadingAnchor, constant: -8),
            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 3),
            detailLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(device: DeviceInfo) {
        nameLabel.stringValue = device.name ?? "iPhone"
        let model = device.productType ?? "iPhone"
        let version = device.productVersion.map { "iOS \($0)" } ?? "iOS"
        let shortUdid = String(device.udid.prefix(8)) + "…"
        detailLabel.stringValue = "\(model) · \(version) · \(shortUdid)"

        let isUsb = device.isUSB
        if isUsb {
            icon.image = NSImage(systemSymbolName: "cable.connector", accessibilityDescription: "Cavo USB")?
                .withSymbolConfiguration(.init(pointSize: 18, weight: .semibold))
            icon.contentTintColor = .systemGreen
            badgeLabel.stringValue = "⚡ Cavo USB · 0–3 ms"
            badgeLabel.textColor = .systemGreen
            badgeContainer.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.12).cgColor
            badgeContainer.layer?.borderColor = NSColor.systemGreen.withAlphaComponent(0.35).cgColor
            toolTip = "\(device.name ?? "iPhone") (Cavo USB)\nLatenza ultra-bassa (0–3 ms)\n\(model) · \(version)\nUDID \(device.udid)"
        } else {
            icon.image = NSImage(systemSymbolName: "wifi", accessibilityDescription: "Wi-Fi")?
                .withSymbolConfiguration(.init(pointSize: 18, weight: .semibold))
            icon.contentTintColor = .systemBlue
            badgeLabel.stringValue = "📶 Wi-Fi"
            badgeLabel.textColor = .systemBlue
            badgeContainer.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.12).cgColor
            badgeContainer.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.35).cgColor
            toolTip = "\(device.name ?? "iPhone") (Wi-Fi)\nConnessione senza fili su rete locale\n\(model) · \(version)\nUDID \(device.udid)"
        }
    }
}
