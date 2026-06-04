//
//  SessionStore.swift
//  CC Status
//
//  Loads per-session and per-subagent state files written by the Claude Code
//  hooks (~/.claude/cc-status/*.json) and groups them into a project -> agents
//  tree via SessionGrouping. Stale files are pruned from disk on each load.
//

import Cocoa

enum SessionStore {

    /// Main sessions not updated for this long are considered dead
    /// (e.g. Claude Code crashed without firing SessionEnd) and removed.
    static let staleSeconds = 6 * 3600

    /// Agents not updated for this long are dropped. Much shorter than
    /// staleSeconds: a subagent whose SubagentStop never fired is almost
    /// certainly done/dead, and agents are short-lived. Tunable.
    static let agentStaleSeconds = 5 * 60

    static var stateDirectory: String {
        NSString(string: "~/.claude/cc-status").expandingTildeInPath
    }

    static func load() -> [ProjectRow] {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: stateDirectory, withIntermediateDirectories: true)
        guard let files = try? fm.contentsOfDirectory(atPath: stateDirectory) else { return [] }

        let now = Int(Date().timeIntervalSince1970)
        var records: [StatusRecord] = []

        for f in files where f.hasSuffix(".json") {
            let path = stateDirectory + "/" + f
            guard let data = fm.contents(atPath: path),
                  let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            else { continue }

            let ts = (obj["ts"] as? NSNumber)?.intValue ?? 0
            let agentId = obj["agent_id"] as? String
            let cutoff = (agentId != nil) ? agentStaleSeconds : staleSeconds

            // Prune stale files from disk and skip them.
            if now - ts > cutoff {
                try? fm.removeItem(atPath: path)
                continue
            }

            records.append(StatusRecord(
                state: obj["state"] as? String ?? "idle",
                project: obj["project"] as? String ?? "?",
                cwd: obj["cwd"] as? String ?? "",
                ts: ts,
                agentId: agentId,
                agentType: obj["agent_type"] as? String
            ))
        }

        return SessionGrouping.build(records: records,
                                     now: now,
                                     sessionStale: staleSeconds,
                                     agentStale: agentStaleSeconds)
    }
}

func stateColor(_ state: String) -> NSColor {
    switch state {
    case "working":   return .systemOrange
    case "attention": return .systemRed
    default:          return .systemGreen
    }
}

func stateSymbol(_ state: String) -> String {
    switch state {
    case "working":   return "▶"
    case "attention": return "!"
    default:          return "✓"
    }
}
