import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var state: AppState
    @State private var slotSheet: SlotSheetItem?
    private let tt = Timetable.shared

    struct SlotSheetItem: Identifiable { let id: String }

    var body: some View {
        let plan = state.plan
        let clashes = plan.clashes
        let codes = state.selected.sorted()
        ScreenScroll {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your week").font(.app(.largeTitle, .bold)).foregroundStyle(Theme.ink)
                Text("Lectures are fixed. We pick lab and seminar slots that avoid clashes; you can change them.")
                    .font(.app(.subheadline)).foregroundStyle(Theme.sub)
            }
            if state.selected.isEmpty {
                Banner(kind: .info, text: "No courses yet. Match or pick your courses on the **Courses** tab first.")
                Button("Go to Courses") { state.coursesSection = .match; state.tab = .courses }.buttonStyle(PrimaryButtonStyle())
            } else {
                statusBanner(plan: plan, clashes: clashes, codes: codes)
                clashList(clashes)
                AddToCalendarButton()
                HStack(spacing: 10) {
                    StatTile(value: "\(codes.count)", label: "courses")
                    StatTile(value: "\(plan.items.count)", label: "classes a week")
                    StatTile(value: "\(clashes.count)", label: clashes.count == 1 ? "clash" : "clashes", tone: clashes.isEmpty ? .good : .bad)
                }
                let credits = AppState.ects(of: codes)
                ECTSMeter(total: credits.total, unknown: credits.unknown, minimum: $state.minECTS)
                WeekGrid(items: plan.items, clashing: Set(clashes.flatMap { [$0.a.id, $0.b.id] }),
                         onSlotTap: { s in slotSheet = SlotSheetItem(id: s.code + "|" + s.type.rawValue) })
                    .panelCard(padding: 6)
                Label("Tap a lab or seminar to change its group and time. Tap a lecture for course details.", systemImage: "hand.tap")
                    .font(.app(.caption)).foregroundStyle(Theme.sub)
                choiceList(plan)
                groupSection(plan)
                SectionTitle(title: "Your courses")
                Card { legend(codes: codes) }
            }
        }
        .navigationTitle("Your week")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $slotSheet) { item in
            if let choice = state.plan.choices.first(where: { $0.id == item.id }) {
                NavigationStack {
                    SlotSheet(choice: choice, plan: state.plan, lock: state.locks[choice.id]) { i in
                        state.locks[choice.id] = i
                        slotSheet = nil
                    }
                    .shellNavigationBar()
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    @ViewBuilder
    private func statusBanner(plan: Plan, clashes: [Clash], codes: [String]) -> some View {
        let years = Set(codes.compactMap { tt.course($0)?.year })
        let who = state.firstName.isEmpty ? "Your" : "\(state.firstName), your"
        let hard = clashes.filter { $0.isBetweenLectures }.count
        if clashes.isEmpty {
            Banner(kind: .good, text: "**\(who) week works: no clashes.** \(codes.count) courses\(years.count > 1 ? " from \(years.count) different years" : ""), \(plan.items.count) classes a week.")
        } else {
            Banner(kind: .bad, text: "**\(who) week has \(clashes.count) clash\(clashes.count > 1 ? "es" : "").** " + (hard > 0 ? "\(hard) between lectures, which can't be moved: talk to your Erasmus coordinator before your Learning Agreement is final." : "We couldn't avoid them by moving labs. Ask the lab teachers about another group."))
        }
        let ro = codes.compactMap { tt.course($0) }.filter { $0.isRomanian }
        if !ro.isEmpty {
            Banner(kind: .warn, text: "🇷🇴 **\(ro.count) of your courses \(ro.count > 1 ? "are" : "is") taught in Romanian:** \(ro.map { $0.name }.joined(separator: ", ")). Check with your coordinator that this works for you.")
        }
    }

    private func legend(codes: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(codes, id: \.self) { code in
                if let c = tt.course(code) {
                    NavigationLink(value: CourseRoute(code: code)) {
                        HStack(spacing: 8) {
                            FacultyDot(faculty: c.faculty)
                            Text(c.name).font(.app(.caption)).foregroundStyle(Theme.accent).lineLimit(1)
                            YearTag(year: c.year)
                            if c.isOtherFaculty { FacultyTag(course: c) }
                            if c.isRomanian { LanguageTag(course: c, compact: true) }
                            Spacer()
                            Image(systemName: "chevron.right").font(.app(.caption2)).foregroundStyle(Theme.faint)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func clashList(_ clashes: [Clash]) -> some View {
        if !clashes.isEmpty {
                        ForEach(clashes) { k in
                let a = tt.course(k.a.code), b = tt.course(k.b.code)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Days.short[k.a.day]) \(k.overlap.start):00–\(k.overlap.end):00 · \(Weeks.label(k.overlap.weeks))").font(.app(.subheadline, .bold))
                    Text("\(a?.name ?? k.a.code) \(k.a.type.label.lowercased()) vs \(b?.name ?? k.b.code) \(k.b.type.label.lowercased())").font(.app(.subheadline))
                    Text(k.isBetweenLectures
                         ? "Both are lectures with no other slot. Talk to your Erasmus coordinator about your Learning Agreement, or agree catch-up with the lecturer."
                         : "No free slot found for this lab or seminar. Ask the teacher whether you can join another group.")
                        .font(.app(.caption)).foregroundStyle(Theme.sub)
                }
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(k.isBetweenLectures ? Theme.errBg : Theme.warnBg, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(k.isBetweenLectures ? Theme.errBg : Theme.warnLine, lineWidth: 1))
            }
        }
    }

    /// One group per year: all labs and seminars of that year follow it.
    @ViewBuilder
    private func groupSection(_ plan: Plan) -> some View {
        let keys = plan.groupOptions.keys.sorted()
        if !keys.isEmpty {
            SectionTitle(title: "Your groups",
                         subtitle: "Each year's labs and seminars run per group, at different times. Pick yours, or let the app pick the group with the fewest clashes.")
            ForEach(keys, id: \.self) { key in
                GroupPicker(key: key, plan: plan,
                            isAuto: state.groups[key] == nil,
                            select: { state.setGroup(key, to: $0) })
            }
        }
    }

    @ViewBuilder
    private func choiceList(_ plan: Plan) -> some View {
        if !plan.choices.isEmpty {
            SectionTitle(title: "Lab and seminar times",
                         subtitle: "Each group meets at a different time. Pick the group that fits your week; your choice is kept until you change it.")
            ForEach(plan.choices) { choice in
                SlotPicker(choice: choice, plan: plan,
                           lock: state.locks[choice.id],
                           select: { state.locks[choice.id] = $0 })
            }
            if !state.locks.isEmpty {
                Button("Let the app choose my slots again") { state.locks = [:] }.font(.app(.subheadline))
            }
        }
    }
}

/// Group menu for one year: each group shows how many clashes it brings.
struct GroupPicker: View {
    let key: String
    let plan: Plan
    let isAuto: Bool
    let select: (String?) -> Void

    var body: some View {
        let current = plan.groups[key]
        let costs = plan.groupCost[key] ?? [:]
        let best = costs.values.min() ?? 0
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Groups.label(key)).font(.app(.subheadline, .semibold)).foregroundStyle(Theme.ink)
                Text(isAuto ? "Picked for you: fewest clashes" : "Your pick")
                    .font(.app(.caption)).foregroundStyle(Theme.sub)
            }
            Spacer()
            Menu {
                Button { select(nil) } label: {
                    Label("Automatic (fewest clashes)", systemImage: isAuto ? "checkmark" : "wand.and.stars")
                }
                Divider()
                ForEach(plan.groupOptions[key] ?? [], id: \.self) { g in
                    let extra = (costs[g] ?? 0) - best
                    Button { select(g) } label: {
                        Label("Group \(g) – \(extra == 0 ? "fewest clashes" : "+\(extra) clash hours")",
                              systemImage: (!isAuto && g == current) ? "checkmark" : (extra == 0 ? "circle" : "exclamationmark.triangle"))
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text("Group \(current ?? "–")").font(.app(.subheadline, .semibold))
                    Image(systemName: "chevron.up.chevron.down").font(.app(.caption))
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Theme.ground, in: Capsule())
                .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
                .foregroundStyle(Theme.ink)
            }
            .accessibilityLabel("\(Groups.label(key)), group \(current ?? "none"). Change group")
        }
        .panelCard(padding: 12)
    }
}

/// One lab/seminar/project with several groups. Each option says whether it fits around the rest of the week.
struct SlotPicker: View {
    let choice: SlotChoice
    let plan: Plan
    let lock: Int?
    let select: (Int) -> Void
    private let tt = Timetable.shared

    private typealias Option = SlotOption
    private var options: [Option] { SlotOption.all(choice: choice, plan: plan) }

    var body: some View {
        let opts = options
        let currentIndex = plan.chosen[choice.id].flatMap { cur in choice.options.firstIndex(of: cur) }
        let current = currentIndex.map { opts[$0] }
        let free = opts.filter { $0.fits }
        let name = tt.course(choice.code)?.name ?? choice.code

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.app(.subheadline, .semibold)).foregroundStyle(Theme.ink)
                    Text("\(choice.type.label) · \(free.count) of \(opts.count) groups fit your week")
                        .font(.app(.caption)).foregroundStyle(Theme.sub)
                }
                Spacer()
                if lock != nil { ChipTag(text: "Your pick") }
            }

            Menu {
                // Groups that fit come first; the index stays the slot's real position, so a pick never shifts.
                ForEach(opts.sorted { ($0.fits ? 0 : 1, $0.index) < ($1.fits ? 0 : 1, $1.index) }) { o in
                    Button { select(o.index) } label: {
                        Label(label(o), systemImage: o.index == currentIndex ? "checkmark" : (o.fits ? "circle" : "exclamationmark.triangle"))
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: (current?.fits ?? false) ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle((current?.fits ?? false) ? Theme.ok : Theme.warnInk)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(current.map { slotText($0.session) } ?? "Choose a group")
                            .font(.app(.subheadline)).foregroundStyle(Theme.ink)
                        if let c = current, !c.fits {
                            Text("Clashes with \(clashText(c))").font(.app(.caption)).foregroundStyle(Theme.sub)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.app(.caption)).foregroundStyle(Theme.faint)
                }
                .padding(10)
                .background(Theme.ground, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .accessibilityLabel("\(name) \(choice.type.label), change group")

            if let c = current, !c.fits, let firstFree = free.first {
                Button { select(firstFree.index) } label: {
                    Label("Switch to a group that fits: \(firstFree.session.timeText)", systemImage: "arrow.triangle.2.circlepath")
                        .font(.app(.caption, .semibold))
                }
            } else if free.isEmpty {
                Text("No group fits around your other classes. The one with the least overlap is picked; ask your coordinator if you can attend another group.")
                    .font(.app(.caption)).foregroundStyle(Theme.sub)
            }
        }
        .panelCard(padding: 12)
    }

    private func slotText(_ s: Session) -> String {
        var parts: [String] = []
        if s.groups != "?" && s.groups != "*" { parts.append(s.groupsText.prefix(1).uppercased() + s.groupsText.dropFirst()) }
        parts.append(s.timeText)
        if !s.room.isEmpty { parts.append(s.room) }
        return parts.joined(separator: " · ")
    }

    private func clashText(_ o: Option) -> String {
        let names = o.conflicts.map { "\(tt.course($0.code)?.name ?? $0.code) (\($0.type.label.lowercased()))" }
        return Array(Set(names)).sorted().joined(separator: ", ")
    }

    private func label(_ o: Option) -> String {
        o.fits ? slotText(o.session) : "\(slotText(o.session)) – clashes with \(clashText(o))"
    }
}

// MARK: - Week grid

struct WeekGrid: View {
    let items: [Session]
    let clashing: Set<Int>
    /// Labs, seminars and projects with several groups: tapping one opens the group picker.
    var onSlotTap: ((Session) -> Void)? = nil

    private let firstHour = 8, lastHour = 21
    private let hourHeight: CGFloat = 46
    private let timeColumn: CGFloat = 30

    var body: some View {
        GeometryReader { geo in
            let dayWidth = (geo.size.width - timeColumn) / 5
            ZStack(alignment: .topLeading) {
                // Hour lines and labels
                ForEach(firstHour...lastHour, id: \.self) { h in
                    let y = CGFloat(h - firstHour) * hourHeight + 20
                    Path { p in p.move(to: CGPoint(x: timeColumn, y: y)); p.addLine(to: CGPoint(x: geo.size.width, y: y)) }
                        .stroke(Theme.line, lineWidth: 0.5)
                    Text("\(h)").font(.app(size: 10)).foregroundStyle(Theme.sub)
                        .frame(width: timeColumn - 4, alignment: .trailing)
                        .offset(x: 0, y: y - 6)
                }
                // Day headers
                ForEach(0..<5, id: \.self) { d in
                    Text(Days.short[d]).font(.app(.caption, .bold)).foregroundStyle(Theme.ink)
                        .frame(width: dayWidth)
                        .offset(x: timeColumn + CGFloat(d) * dayWidth, y: 0)
                }
                // Classes
                ForEach(layout(), id: \.session.id) { block in
                    let s = block.session
                    let w = dayWidth / CGFloat(block.lanes)
                    Group {
                        if !s.isFixed, let tap = onSlotTap {
                            Button { tap(s) } label: { ClassBlock(session: s, clash: clashing.contains(s.id)) }
                                .accessibilityHint("Change group and time")
                        } else {
                            NavigationLink(value: CourseRoute(code: s.code)) {
                                ClassBlock(session: s, clash: clashing.contains(s.id))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(width: w - 3, height: CGFloat(s.end - s.start) * hourHeight - 3)
                    .offset(x: timeColumn + CGFloat(s.day) * dayWidth + CGFloat(block.lane) * w + 1.5,
                            y: CGFloat(s.start - firstHour) * hourHeight + 21.5)
                }
            }
        }
        .frame(height: CGFloat(lastHour - firstHour) * hourHeight + 24)
    }

    private struct Block { let session: Session; let lane: Int; let lanes: Int }

    /// Puts overlapping classes side by side.
    private func layout() -> [Block] {
        var out: [Block] = []
        for d in 0..<5 {
            let day = items.filter { $0.day == d }.sorted { ($0.start, -$0.end) < ($1.start, -$1.end) }
            var laneEnds: [Int] = []
            var lanes: [Int: Int] = [:]
            for s in day {
                if let l = laneEnds.firstIndex(where: { $0 <= s.start }) { laneEnds[l] = s.end; lanes[s.id] = l }
                else { laneEnds.append(s.end); lanes[s.id] = laneEnds.count - 1 }
            }
            for s in day {
                let group = day.filter { $0.start < s.end && $0.end > s.start }
                let n = (group.compactMap { lanes[$0.id] }.max() ?? 0) + 1
                out.append(Block(session: s, lane: lanes[s.id] ?? 0, lanes: n))
            }
        }
        return out
    }
}

struct ClassBlock: View {
    let session: Session
    let clash: Bool

    var body: some View {
        let course = Timetable.shared.course(session.code)
        HStack(spacing: 0) {
            Rectangle().fill(Theme.faculty(course?.faculty ?? "AC")).frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 2) {
                    Text(session.code).font(.code(size: 10)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
                    if course?.isRomanian == true { Text("RO").font(.app(size: 8, .bold)).foregroundStyle(Theme.sub) }
                }
                Text(session.type.label).font(.app(size: 9)).foregroundStyle(Theme.sub).lineLimit(1)
                Text(session.room).font(.app(size: 9)).foregroundStyle(Theme.faint).lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(3)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(clash ? Theme.errBg : Theme.chip, in: RoundedRectangle(cornerRadius: 5))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(clash ? Theme.err : Theme.line, lineWidth: clash ? 1.5 : 0.5))
    }
}


/// One possible group/slot for a lab, seminar or project, and what it would clash with.
struct SlotOption: Identifiable {
    let index: Int
    let session: Session
    let conflicts: [Session]
    var id: Int { index }
    var fits: Bool { conflicts.isEmpty }

    static func all(choice: SlotChoice, plan: Plan) -> [SlotOption] {
        let current = plan.chosen[choice.id]
        // Everything else in the week: fixed classes and the slots picked for the other choices.
        let others = plan.items.filter { $0.id != current?.id && !($0.code == choice.code && $0.type == choice.type) }
        return choice.options.enumerated().map { i, o in
            SlotOption(index: i, session: o, conflicts: others.filter { overlap(o, $0) != nil })
        }
    }
}

/// Full list of groups for one lab/seminar, opened by tapping it in the week grid.
struct SlotSheet: View {
    let choice: SlotChoice
    let plan: Plan
    let lock: Int?
    let select: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    private let tt = Timetable.shared

    var body: some View {
        let opts = SlotOption.all(choice: choice, plan: plan)
        let currentIndex = plan.chosen[choice.id].flatMap { cur in choice.options.firstIndex(of: cur) }
        let sorted = opts.sorted { ($0.fits ? 0 : 1, $0.index) < ($1.fits ? 0 : 1, $1.index) }
        ScreenScroll {
            VStack(alignment: .leading, spacing: 4) {
                Text(tt.course(choice.code)?.name ?? choice.code).font(.app(.title2, .bold)).foregroundStyle(Theme.ink)
                Text("\(choice.type.label) · \(opts.filter { $0.fits }.count) of \(opts.count) groups fit your week")
                    .font(.app(.subheadline)).foregroundStyle(Theme.sub)
            }
            Card(padding: 0) {
                ForEach(Array(sorted.enumerated()), id: \.element.id) { i, o in
                    if i > 0 { Divider().overlay(Theme.line).padding(.leading, 52) }
                    Button { select(o.index) } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: o.index == currentIndex ? "checkmark.circle.fill" : (o.fits ? "circle" : "exclamationmark.triangle"))
                                .font(.system(size: 20))
                                .foregroundStyle(o.index == currentIndex ? Theme.accent : (o.fits ? Theme.faint : Theme.warnInk))
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(o.session.groups == "?" ? "Any group" : o.session.groupsText.prefix(1).uppercased() + o.session.groupsText.dropFirst())
                                    .font(.app(.subheadline, .semibold)).foregroundStyle(Theme.ink)
                                Text("\(o.session.timeText)\(o.session.room.isEmpty ? "" : " · " + o.session.room)")
                                    .font(.app(.footnote)).foregroundStyle(Theme.sub)
                                if o.fits {
                                    Label("Fits your week", systemImage: "checkmark").font(.app(.caption, .semibold)).foregroundStyle(Theme.sub)
                                } else {
                                    Text("Clashes with " + Array(Set(o.conflicts.map { (tt.course($0.code)?.name ?? $0.code) + " (" + $0.type.label.lowercased() + ")" })).sorted().joined(separator: ", "))
                                        .font(.app(.caption)).foregroundStyle(Theme.sub)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(o.index == currentIndex ? .isSelected : [])
                }
            }
            Text("Your pick stays until you change it. Picking a group per year on the Schedule tab moves all labs of that year.")
                .font(.app(.caption)).foregroundStyle(Theme.faint)
        }
        .navigationTitle("Choose a group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
}
