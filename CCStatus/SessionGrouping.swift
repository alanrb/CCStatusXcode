//
//  SessionGrouping.swift
//  CC Status
//
//  Pure (Foundation-only, no AppKit) logic that turns raw state records into
//  a project -> agents tree. Kept free of Cocoa so it can be unit-tested with
//  a standalone `swiftc` invocation (see Tests/main.swift).
//

import Foundation

/// One raw status record parsed from a state file.
struct StatusRecord {
    let state: String        // "working" | "attention" | "idle"
    let project: String
    let cwd: String
    let ts: Int
    let agentId: String?     // nil for the main thread
    let agentType: String?   // present for subagents
}

/// A subagent shown as an indented row.
struct AgentRow {
    let state: String
    let agentType: String
    let ts: Int
}

/// A project (one cwd) shown as a top-level row, with its active agents.
struct ProjectRow {
    let state: String        // rolled-up: most urgent of main + agents
    let project: String
    let cwd: String
    let ts: Int
    let agents: [AgentRow]
}

enum SessionGrouping {

    /// Urgency ranking: attention > working > idle.
    static func urgency(_ state: String) -> Int {
        switch state {
        case "attention": return 2
        case "working":   return 1
        default:          return 0
        }
    }

    static func mostUrgent(_ states: [String]) -> String {
        states.max(by: { urgency($0) < urgency($1) }) ?? "idle"
    }

    /// Build the project -> agents tree.
    /// - sessionStale: drop main-thread records older than this many seconds.
    /// - agentStale:   drop agent records older than this many seconds.
    static func build(records: [StatusRecord],
                      now: Int,
                      sessionStale: Int,
                      agentStale: Int) -> [ProjectRow] {

        let mains = records
            .filter { $0.agentId == nil }
            .filter { now - $0.ts <= sessionStale }
        let agents = records
            .filter { $0.agentId != nil }
            .filter { now - $0.ts <= agentStale }

        // Dedup main sessions by cwd, newest ts wins.
        var mainByCwd: [String: StatusRecord] = [:]
        for m in mains {
            if let e = mainByCwd[m.cwd], e.ts >= m.ts { continue }
            mainByCwd[m.cwd] = m
        }

        // Group agents by cwd, sorted by ts ascending.
        var agentsByCwd: [String: [AgentRow]] = [:]
        for a in agents {
            agentsByCwd[a.cwd, default: []].append(
                AgentRow(state: a.state, agentType: a.agentType ?? "agent", ts: a.ts))
        }
        for (k, v) in agentsByCwd {
            agentsByCwd[k] = v.sorted { $0.ts < $1.ts }
        }

        // One project row per cwd that has a main session and/or agents.
        var cwds = Set(mainByCwd.keys)
        cwds.formUnion(agentsByCwd.keys)

        var rows: [ProjectRow] = []
        for cwd in cwds {
            let agentRows = agentsByCwd[cwd] ?? []
            let main = mainByCwd[cwd]

            var states = agentRows.map { $0.state }
            if let m = main { states.append(m.state) }

            let project = main?.project ?? (cwd as NSString).lastPathComponent
            let ts = max(main?.ts ?? 0, agentRows.map { $0.ts }.max() ?? 0)

            rows.append(ProjectRow(
                state: mostUrgent(states),
                project: project.isEmpty ? "unknown" : project,
                cwd: cwd,
                ts: ts,
                agents: agentRows))
        }
        return rows.sorted { ($0.project, $0.cwd) < ($1.project, $1.cwd) }
    }
}
