//
//  main.swift
//  CC Status
//
//  Entry point. Accessory activation policy = no Dock icon,
//  the app exists only as the floating status panel.
//

import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
