import Foundation

func expect(_ cond: Bool, _ msg: String) {
    if !cond { print("FAIL: \(msg)"); exit(1) }
    print("ok: \(msg)")
}

let now = 1_000_000

// 1. dedup mains by cwd, newest ts wins
let r1 = [
    StatusRecord(state: "idle",    project: "A", cwd: "/a", ts: now-10, agentId: nil, agentType: nil),
    StatusRecord(state: "working", project: "A", cwd: "/a", ts: now-1,  agentId: nil, agentType: nil),
]
let p1 = SessionGrouping.build(records: r1, now: now, sessionStale: 1000, agentStale: 300)
expect(p1.count == 1, "dedup to one project")
expect(p1[0].state == "working", "newest main state wins")

// 2. rollup: main idle + agent working -> working, agent attached
let r2 = [
    StatusRecord(state: "idle",    project: "A", cwd: "/a", ts: now-1, agentId: nil,   agentType: nil),
    StatusRecord(state: "working", project: "A", cwd: "/a", ts: now-1, agentId: "ag1", agentType: "Explore"),
]
let p2 = SessionGrouping.build(records: r2, now: now, sessionStale: 1000, agentStale: 300)
expect(p2[0].state == "working", "rollup main idle + agent working = working")
expect(p2[0].agents.count == 1, "one agent row")
expect(p2[0].agents[0].agentType == "Explore", "agent type label")

// 3. rollup: attention beats working
let r3 = [
    StatusRecord(state: "working",   project: "A", cwd: "/a", ts: now-1, agentId: nil,   agentType: nil),
    StatusRecord(state: "attention", project: "A", cwd: "/a", ts: now-1, agentId: "ag1", agentType: "x"),
]
let p3 = SessionGrouping.build(records: r3, now: now, sessionStale: 1000, agentStale: 300)
expect(p3[0].state == "attention", "attention beats working in rollup")

// 4. stale agent dropped and ignored in rollup
let r4 = [
    StatusRecord(state: "idle",    project: "A", cwd: "/a", ts: now-1,    agentId: nil,   agentType: nil),
    StatusRecord(state: "working", project: "A", cwd: "/a", ts: now-9999, agentId: "ag1", agentType: "x"),
]
let p4 = SessionGrouping.build(records: r4, now: now, sessionStale: 100000, agentStale: 300)
expect(p4[0].agents.isEmpty, "stale agent dropped")
expect(p4[0].state == "idle", "rollup ignores stale agent")

// 5. two agents same type, sorted by ts ascending
let r5 = [
    StatusRecord(state: "idle",    project: "A", cwd: "/a", ts: now-1, agentId: nil, agentType: nil),
    StatusRecord(state: "working", project: "A", cwd: "/a", ts: now-2, agentId: "b", agentType: "Explore"),
    StatusRecord(state: "working", project: "A", cwd: "/a", ts: now-5, agentId: "a", agentType: "Explore"),
]
let p5 = SessionGrouping.build(records: r5, now: now, sessionStale: 1000, agentStale: 300)
expect(p5[0].agents.count == 2, "two agent rows same type")
expect(p5[0].agents[0].ts <= p5[0].agents[1].ts, "agents sorted by ts asc")

// 6. orphan agent (no main) still yields a project row
let r6 = [
    StatusRecord(state: "working", project: "A", cwd: "/a", ts: now-1, agentId: "x", agentType: "Explore"),
]
let p6 = SessionGrouping.build(records: r6, now: now, sessionStale: 1000, agentStale: 300)
expect(p6.count == 1, "orphan agent yields a project row")
expect(p6[0].state == "working", "orphan project rolled up from agent")
expect(p6[0].project == "a", "orphan project name from cwd basename")

print("ALL PASS")
