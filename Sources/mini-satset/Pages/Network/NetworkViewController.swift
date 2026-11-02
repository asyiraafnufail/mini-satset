import AppKit

final class NetworkViewController: NSViewController {
    private let engine = SpeedTestEngine()

    private let dlValueLabel = NSTextField(labelWithString: "--")
    private let ulValueLabel = NSTextField(labelWithString: "--")
    private let rpmValueLabel = NSTextField(labelWithString: "Responsiveness: -- RPM")
    private let statusLabel = NSTextField(labelWithString: "Ready to test network speed")
    private let actionButton = NSButton()
    private let spinner = NSProgressIndicator()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 290))
        setupUI()
    }

    private func setupUI() {
        // Container Card
        let card = NSView(frame: NSRect(x: 16, y: 80, width: 288, height: 180))
        card.wantsLayer = true
        card.layer?.cornerRadius = 10
        card.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        view.addSubview(card)

        // Download Section
        let dlTitle = NSTextField(labelWithString: "DOWNLOAD")
        dlTitle.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        dlTitle.textColor = .secondaryLabelColor
        dlTitle.frame = NSRect(x: 16, y: 140, width: 120, height: 14)
        card.addSubview(dlTitle)

        dlValueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 26, weight: .bold)
        dlValueLabel.textColor = .labelColor
        dlValueLabel.frame = NSRect(x: 16, y: 100, width: 120, height: 34)
        card.addSubview(dlValueLabel)

        let dlUnit = NSTextField(labelWithString: "Mbps")
        dlUnit.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        dlUnit.textColor = .secondaryLabelColor
        dlUnit.frame = NSRect(x: 16, y: 84, width: 60, height: 14)
        card.addSubview(dlUnit)

        // Upload Section
        let ulTitle = NSTextField(labelWithString: "UPLOAD")
        ulTitle.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        ulTitle.textColor = .secondaryLabelColor
        ulTitle.frame = NSRect(x: 156, y: 140, width: 120, height: 14)
        card.addSubview(ulTitle)

        ulValueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 26, weight: .bold)
        ulValueLabel.textColor = .labelColor
        ulValueLabel.frame = NSRect(x: 156, y: 100, width: 120, height: 34)
        card.addSubview(ulValueLabel)

        let ulUnit = NSTextField(labelWithString: "Mbps")
        ulUnit.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        ulUnit.textColor = .secondaryLabelColor
        ulUnit.frame = NSRect(x: 156, y: 84, width: 60, height: 14)
        card.addSubview(ulUnit)

        // Separator inside card
        let sep = NSBox(frame: NSRect(x: 16, y: 70, width: 256, height: 1))
        sep.boxType = .separator
        card.addSubview(sep)

        // Latency / RPM
        rpmValueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        rpmValueLabel.textColor = .secondaryLabelColor
        rpmValueLabel.frame = NSRect(x: 16, y: 40, width: 256, height: 16)
        card.addSubview(rpmValueLabel)

        // Status
        statusLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        statusLabel.textColor = .tertiaryLabelColor
        statusLabel.frame = NSRect(x: 16, y: 16, width: 256, height: 16)
        card.addSubview(statusLabel)

        // Action Button
        actionButton.frame = NSRect(x: 70, y: 24, width: 180, height: 32)
        actionButton.title = "Start Speed Test"
        actionButton.bezelStyle = .rounded
        actionButton.target = self
        actionButton.action = #selector(handleActionClick)
        view.addSubview(actionButton)

        // Spinner
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.frame = NSRect(x: 258, y: 31, width: 16, height: 16)
        spinner.isDisplayedWhenStopped = false
        view.addSubview(spinner)
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        engine.cancelTest()
        spinner.stopAnimation(nil)
        actionButton.isEnabled = true
    }

    @objc private func handleActionClick() {
        actionButton.isEnabled = false
        spinner.startAnimation(nil)
        statusLabel.stringValue = "Running networkQuality..."
        dlValueLabel.stringValue = "--"
        ulValueLabel.stringValue = "--"
        rpmValueLabel.stringValue = "RPM: measuring..."

        engine.startTest(
            onProgress: { [weak self] msg in
                self?.statusLabel.stringValue = msg
            },
            onCompletion: { [weak self] result in
                guard let self = self else { return }
                self.spinner.stopAnimation(nil)
                self.actionButton.isEnabled = true

                switch result {
                case .success(let data):
                    self.dlValueLabel.stringValue = String(format: "%.1f", data.downloadMbps)
                    self.ulValueLabel.stringValue = String(format: "%.1f", data.uploadMbps)
                    self.rpmValueLabel.stringValue = "Responsiveness: \(data.rpm) RPM • Latency: \(data.pingMs) ms"
                    self.statusLabel.stringValue = "Test completed."
                case .failure(let error):
                    self.statusLabel.stringValue = error.localizedDescription
                }
            }
        )
    }
}
