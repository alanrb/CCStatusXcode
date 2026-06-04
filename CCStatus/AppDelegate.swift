//
//  AppDelegate.swift
//  CC Status
//
//  Always-on-top floating panel showing all Claude Code session states.
//

import Cocoa
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {

    var panel: NSPanel!
    var stack: NSStackView!
    var timer: Timer?
    var contextMenu: NSMenu!

    func applicationDidFinishLaunching(_ note: Notification) {
        panel = NSPanel(
            contentRect: NSRect(x: 80, y: 80, width: 240, height: 60),
            styleMask: [.titled, .nonactivatingPanel, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating                      // always on top
        panel.hidesOnDeactivate = false              // stay visible when other apps are active
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = true     // drag anywhere to move
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.92)
        panel.hasShadow = true
        panel.setFrameAutosaveName("CCStatusPanel")  // remember position between launches

        stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 5
        // extra right inset leaves room for the × so header text never runs under it
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 12, bottom: 12, right: 32)
        stack.translatesAutoresizingMaskIntoConstraints = false

        // container holds the status rows plus an always-visible quit button
        let container = NSView()
        container.addSubview(stack)

        let closeButton = NSButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Quit CC Status")?
            .withSymbolConfiguration(symbolConfig)
        closeButton.imagePosition = .imageOnly
        closeButton.isBordered = false
        closeButton.bezelStyle = .regularSquare
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.toolTip = "Quit CC Status"
        closeButton.target = NSApp
        closeButton.action = #selector(NSApplication.terminate(_:))
        container.addSubview(closeButton)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            closeButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
        ])

        panel.contentView = container

        buildContextMenu()
        stack.menu = contextMenu

        refresh()
        panel.orderFrontRegardless()

        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    // MARK: - Right-click menu

    func buildContextMenu() {
        contextMenu = NSMenu()

        let loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        loginItem.target = self
        contextMenu.addItem(loginItem)

        let folderItem = NSMenuItem(
            title: "Open State Folder",
            action: #selector(openStateFolder(_:)),
            keyEquivalent: ""
        )
        folderItem.target = self
        contextMenu.addItem(folderItem)

        contextMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit CC Status",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        contextMenu.addItem(quitItem)

        contextMenu.delegate = self
    }

    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Launch at login toggle failed: \(error)")
        }
    }

    @objc func openStateFolder(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(URL(fileURLWithPath: SessionStore.stateDirectory, isDirectory: true))
    }

    // MARK: - Rendering

    func makeLabel(_ text: String, color: NSColor, size: CGFloat, bold: Bool = false) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = bold ? NSFont.boldSystemFont(ofSize: size)
                      : NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        l.textColor = color
        l.menu = contextMenu
        return l
    }

    func refresh() {
        for v in stack.arrangedSubviews {
            stack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }

        let projects = SessionStore.load()
        let working   = projects.filter { $0.state == "working" }.count
        let attention = projects.filter { $0.state == "attention" }.count

        let headerText: String
        let headerColor: NSColor
        if projects.isEmpty {
            headerText = "Claude Code · no sessions"
            headerColor = .secondaryLabelColor
        } else if attention > 0 {
            headerText = "Claude Code · \(attention) need you"
            headerColor = .systemRed
        } else if working > 0 {
            headerText = "Claude Code · \(working) working"
            headerColor = .systemOrange
        } else {
            headerText = "Claude Code · all idle"
            headerColor = .systemGreen
        }
        stack.addArrangedSubview(makeLabel(headerText, color: headerColor, size: 11, bold: true))

        let now = Int(Date().timeIntervalSince1970)
        for p in projects {
            let age = max(0, (now - p.ts) / 60)
            let row = RowLabel(labelWithString: "\(stateSymbol(p.state)) \(p.project) · \(p.state) · \(age)m")
            row.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
            row.textColor = stateColor(p.state)
            row.cwd = p.cwd
            row.toolTip = "Click to open \(p.cwd) in VSCode"
            row.menu = contextMenu
            stack.addArrangedSubview(row)

            for a in p.agents {
                let aAge = max(0, (now - a.ts) / 60)
                let arow = RowLabel(labelWithString: "    ↳ \(stateSymbol(a.state)) \(a.agentType) · \(aAge)m")
                arow.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
                arow.textColor = stateColor(a.state)
                arow.cwd = p.cwd
                arow.toolTip = "Click to open \(p.cwd) in VSCode (subagent: \(a.agentType))"
                arow.menu = contextMenu
                stack.addArrangedSubview(arow)
            }
        }

        var size = stack.fittingSize
        size.width = max(size.width, 220)
        panel.setContentSize(size)
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        if let item = menu.items.first(where: { $0.title == "Launch at Login" }) {
            item.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
    }
}
