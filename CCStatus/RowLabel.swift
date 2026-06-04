//
//  RowLabel.swift
//  CC Status
//
//  A label row representing one Claude Code session.
//  Clicking it opens the session's project folder in VSCode.
//

import Cocoa

final class RowLabel: NSTextField {

    var cwd: String = ""

    override func mouseDown(with event: NSEvent) {
        guard !cwd.isEmpty else { return }
        let p = Process()
        p.launchPath = "/usr/bin/open"
        p.arguments = ["-a", "Visual Studio Code", cwd]
        p.launch()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}
