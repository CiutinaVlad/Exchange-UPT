import Foundation

struct Overlap {
    let start: Int
    let end: Int
    let weeks: [Int]
}

func overlap(_ a: Session, _ b: Session) -> Overlap? {
    guard a.day == b.day else { return nil }
    let s = max(a.start, b.start), e = min(a.end, b.end)
    guard e > s else { return nil }
    let w = a.weekSet.intersection(b.weekSet)
    guard !w.isEmpty else { return nil }
    return Overlap(start: s, end: e, weeks: w.sorted())
}

/// A lab, seminar or project that has several possible slots.
struct SlotChoice: Identifiable {
    let code: String
    let type: SessionType
    let options: [Session]
    var id: String { code + "|" + type.rawValue }
}

struct Clash: Identifiable {
    let a: Session
    let b: Session
    let overlap: Overlap
    var id: String { "\(a.id)-\(b.id)" }
    /// Two lectures can't be moved: the student must talk to their coordinator.
    var isBetweenLectures: Bool { a.type == .lecture && b.type == .lecture }
}

/// Which group a student sits in, per year and programme ("2|" = year 2 English, "3|C" = year 3 Romanian Computers).
enum Groups {
    /// Subgroups a session is held for, e.g. "C 1.1,C 1.2" → [("C","1.1"),("C","1.2")]. Empty for "*" and "?".
    static func tokens(_ s: Session) -> [(prefix: String, sub: String)] {
        s.groups.split(separator: ",").compactMap { raw in
            let t = raw.trimmingCharacters(in: .whitespaces)
            let parts = t.split(separator: " ")
            if parts.count == 2, parts[1].contains(".") { return (String(parts[0]), String(parts[1])) }
            if parts.count == 1, t.contains("."), t.first?.isNumber == true { return ("", t) }
            return nil
        }
    }
    static func key(year: Int, prefix: String) -> String { "\(year)|\(prefix)" }
    static func label(_ key: String) -> String {
        let p = key.split(separator: "|", omittingEmptySubsequences: false)
        let year = p.first.map(String.init) ?? "?"
        let prog = p.count > 1 ? String(p[1]) : ""
        let name = prog == "C" ? "Computers, Romanian" : prog == "TI" ? "IT, Romanian" : "English programme"
        return "Year \(year) · \(name)"
    }
    static func matches(_ s: Session, prefix: String, sub: String) -> Bool {
        let t = tokens(s)
        return t.isEmpty || t.contains { $0.prefix == prefix && $0.sub == sub }
    }
}

struct Plan {
    let fixed: [Session]
    let choices: [SlotChoice]
    let chosen: [String: Session]   // SlotChoice.id → chosen session
    /// Group per year/programme key, the groups on offer, and the clash-hours each group would cause.
    var groups: [String: String] = [:]
    var groupOptions: [String: [String]] = [:]
    var groupCost: [String: [String: Int]] = [:]
    var autoGroup: Set<String> = []

    var items: [Session] { fixed + choices.compactMap { chosen[$0.id] } }

    var clashes: [Clash] {
        let all = items
        var out: [Clash] = []
        for i in 0..<all.count {
            for j in (i + 1)..<max(all.count, i + 1) {
                let a = all[i], b = all[j]
                if a.code == b.code && a.type == b.type { continue }
                if let o = overlap(a, b) { out.append(Clash(a: a, b: b, overlap: o)) }
            }
        }
        return out
    }

    static let empty = Plan(fixed: [], choices: [], chosen: [:])
}

enum Scheduler {
    /// Lectures are fixed. Labs, seminars and projects follow the student's group for that year
    /// (picked by the student, or the group with the fewest clashes). `locks` are slots picked by hand
    /// and win over the group.
    static func build(selected: Set<String>, locks: [String: Int], groups userGroups: [String: String] = [:]) -> Plan {
        let tt = Timetable.shared
        var fixed: [Session] = []
        var choices: [SlotChoice] = []
        for code in selected.sorted() {
            let sessions = tt.sessions(for: code)
            fixed += sessions.filter { $0.isFixed }
            for type in [SessionType.lab, .seminar, .project] {
                let opts = sessions.filter { $0.type == type && !$0.isFixed }
                if !opts.isEmpty { choices.append(SlotChoice(code: code, type: type, options: opts)) }
            }
        }
        choices.sort { $0.options.count < $1.options.count }

        // Group key of each choice and the subgroups on offer per key.
        var keyOf: [String: String] = [:]
        var offered: [String: Set<String>] = [:]
        for c in choices {
            guard let year = tt.course(c.code)?.year else { continue }
            for o in c.options {
                for t in Groups.tokens(o) {
                    let k = Groups.key(year: year, prefix: t.prefix)
                    keyOf[c.id] = k
                    offered[k, default: []].insert(t.sub)
                }
            }
        }
        let keys = offered.keys.sorted()
        let options = offered.mapValues { $0.sorted() }

        func cost(_ s: Session, _ placed: [Session]) -> Int {
            placed.reduce(0) { acc, p in
                guard let o = overlap(s, p) else { return acc }
                return acc + (o.end - o.start) * o.weeks.count
            }
        }
        var baseCost = 0
        for i in 0..<fixed.count {
            for j in (i + 1)..<max(fixed.count, i + 1) {
                if let o = overlap(fixed[i], fixed[j]) { baseCost += (o.end - o.start) * o.weeks.count }
            }
        }

        /// Best slots for one group assignment: (clash-hours, chosen session per choice).
        func solve(_ assign: [String: String]) -> (Int, [String: Session]) {
            let opts: [[Session]] = choices.map { c in
                if let lock = locks[c.id], c.options.indices.contains(lock) { return [c.options[lock]] }
                guard let k = keyOf[c.id], let sub = assign[k] else { return c.options }
                let prefix = String(k.split(separator: "|", omittingEmptySubsequences: false).last ?? "")
                let inGroup = c.options.filter { Groups.matches($0, prefix: prefix, sub: sub) }
                return inGroup.isEmpty ? c.options : inGroup     // course without that group: any slot
            }
            var best: [Session]? = nil, bestCost = Int.max, pick: [Session] = [], iterations = 0
            func search(_ i: Int, _ placed: inout [Session], _ c: Int) {
                iterations += 1
                if c >= bestCost || iterations > 60_000 { return }
                if i == choices.count { bestCost = c; best = pick; return }
                for (o, k) in opts[i].map({ ($0, cost($0, placed)) }).sorted(by: { $0.1 < $1.1 }) {
                    pick.append(o); placed.append(o)
                    search(i + 1, &placed, c + k)
                    placed.removeLast(); pick.removeLast()
                }
            }
            var placed = fixed
            search(0, &placed, baseCost)
            var chosen: [String: Session] = [:]
            for (i, s) in (best ?? []).enumerated() where i < choices.count { chosen[choices[i].id] = s }
            return (bestCost == Int.max ? 0 : bestCost, chosen)
        }

        // Fixed keys come from the student; the others are searched (all combinations, capped).
        var assign: [String: String] = [:]
        for k in keys { if let g = userGroups[k], options[k]?.contains(g) == true { assign[k] = g } }
        let free = keys.filter { assign[$0] == nil }
        var combos: [[String: String]] = [[:]]
        for k in free {
            let next = combos.flatMap { c in (options[k] ?? []).map { c.merging([k: $0]) { a, _ in a } } }
            if next.count > 400 { break }
            combos = next
        }
        var best = (cost: Int.max, assign: assign, chosen: [String: Session]())
        for c in combos {
            let a = assign.merging(c) { a, _ in a }
            let (k, ch) = solve(a)
            if k < best.cost { best = (k, a, ch) }
        }
        // Keys the cap left out: first group.
        for k in free where best.assign[k] == nil { best.assign[k] = options[k]?.first }
        if best.cost == Int.max { let r = solve(best.assign); best.cost = r.0; best.chosen = r.1 }

        // Clash-hours for every alternative group, the other keys unchanged (for the group menus).
        var groupCost: [String: [String: Int]] = [:]
        for k in keys {
            for g in options[k] ?? [] {
                var a = best.assign; a[k] = g
                groupCost[k, default: [:]][g] = g == best.assign[k] ? best.cost : solve(a).0
            }
        }

        var plan = Plan(fixed: fixed, choices: choices, chosen: best.chosen)
        plan.groups = best.assign
        plan.groupOptions = options
        plan.groupCost = groupCost
        plan.autoGroup = Set(free)
        return plan
    }
}
