import SwiftUI

/// Home: the first screen after signing in. Everything that needs the student's attention, most urgent first.
struct HomeView: View {
    @EnvironmentObject var state: AppState
    private let tt = Timetable.shared

    /// One item in the "Needs your attention" list.
    private struct Notice: Identifiable {
        let id: String
        let icon: String
        let tone: Banner.Kind
        let title: String
        let detail: String
        let action: String
        let go: () -> Void
    }

    var body: some View {
        let phases = PaperworkView.phases(nonEU: !state.profile.isEU)
        let tasks = phases.flatMap { $0.tasks }
        let open = tasks.filter { !state.done.contains($0.id) }
        let notices = notices()
        let credits = AppState.ects(of: Array(state.selected))
        let clashes = state.plan.clashes

        ScreenScroll {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting).font(.app(.largeTitle, .bold)).foregroundStyle(Theme.ink)
                Text(arrivalText).font(.app(.subheadline)).foregroundStyle(Theme.sub)
            }

            if !notices.isEmpty {
                SectionTitle(title: "Needs your attention", subtitle: nil)
                ForEach(notices) { n in noticeCard(n) }
            } else {
                Banner(kind: .good, text: "**You’re all set for now.** Your courses add up and nothing is due soon.")
            }

            HStack(spacing: 10) {
                StatTile(value: "\(state.selected.count)", label: state.selected.count == 1 ? "course" : "courses")
                StatTile(value: "\(credits.total)/\(state.minECTS)", label: "ECTS", tone: state.selected.isEmpty ? nil : (credits.total >= state.minECTS ? .good : .bad))
                StatTile(value: "\(tasks.count - open.count)/\(tasks.count)", label: "steps done")
            }

            SectionTitle(title: "To do", subtitle: "Deadlines count from your arrival day")
            Card(padding: 0) {
                let upcoming = Array(open.prefix(5))
                if upcoming.isEmpty {
                    Text("Every step is done.").font(.app(.subheadline)).foregroundStyle(Theme.sub).padding(14)
                }
                ForEach(Array(upcoming.enumerated()), id: \.element.id) { i, task in
                    if i > 0 { Divider().overlay(Theme.line).padding(.leading, 52) }
                    TaskRow(task: task, done: false, due: dueDate(task)) {
                        withAnimation { _ = state.done.insert(task.id) }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                }
                Divider().overlay(Theme.line)
                NavigationLink {
                    PaperworkView().shellNavigationBar()
                } label: {
                    LinkRow(title: "All steps", subtitle: "\(open.count) left · before you arrive to before you leave", systemImage: "checklist")
                        .padding(.horizontal, 14).padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }

            if !state.selected.isEmpty {
                SectionTitle(title: "Your week", subtitle: nil)
                Button { state.tab = .schedule } label: {
                    LinkRow(title: clashes.isEmpty ? "No clashes in your week" : "\(clashes.count) \(clashes.count == 1 ? "clash" : "clashes") in your week",
                            subtitle: "\(state.plan.items.count) classes a week · tap to see your timetable",
                            systemImage: "calendar")
                }
                .buttonStyle(.plain)
                .panelCard(padding: 14)
            }
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Notices, most urgent first

    private func notices() -> [Notice] {
        var out: [Notice] = []
        let credits = AppState.ects(of: Array(state.selected))
        if state.selected.isEmpty {
            out.append(Notice(id: "match", icon: "doc.text.viewfinder", tone: .warn,
                              title: "Match your courses first",
                              detail: "Upload your Learning Agreement or pick courses. You can match one now and add the rest later.",
                              action: "Match my courses",
                              go: { state.coursesSection = .match; state.tab = .courses }))
        } else if credits.total < state.minECTS {
            out.append(Notice(id: "ects", icon: "gauge.with.dots.needle.33percent", tone: .warn,
                              title: "\(state.minECTS - credits.total) ECTS short of your minimum",
                              detail: "You have \(credits.total) of \(state.minECTS) ECTS. Match or add more courses when you’re ready.",
                              action: "Add courses",
                              go: { state.coursesSection = .match; state.tab = .courses }))
        }
        let lectureClashes = state.plan.clashes.filter { $0.isBetweenLectures }
        if !lectureClashes.isEmpty {
            out.append(Notice(id: "clash", icon: "exclamationmark.triangle", tone: .bad,
                              title: "\(lectureClashes.count) lecture \(lectureClashes.count == 1 ? "clash" : "clashes")",
                              detail: "Lectures can’t be moved. Talk to your coordinator before you sign your Learning Agreement.",
                              action: "See my week",
                              go: { state.tab = .schedule }))
        }
        if let next = PaperworkView.phases(nonEU: !state.profile.isEU).flatMap({ $0.tasks })
            .first(where: { !state.done.contains($0.id) && $0.dueWorkdays != nil }), let due = dueDate(next) {
            out.append(Notice(id: "due", icon: "clock", tone: .info,
                              title: "Next deadline: \(due.formatted(.dateTime.weekday(.wide).day().month(.wide)))",
                              detail: next.title,
                              action: state.profile.isEU ? "What EU students need" : "What non-EU students need",
                              go: { state.tab = .resources }))
        }
        if state.profile.homeUniversity.isEmpty {
            out.append(Notice(id: "profile", icon: "person.crop.circle.badge.exclamationmark", tone: .info,
                              title: "Finish your profile",
                              detail: "Add your home university and arrival day, so deadlines are right.",
                              action: "Open profile",
                              go: { state.showProfile = true }))
        }
        return out
    }

    private func noticeCard(_ n: Notice) -> some View {
        let fg: Color = n.tone == .bad ? Theme.err : (n.tone == .warn ? Theme.warnInk : Theme.accent)
        let bg: Color = n.tone == .bad ? Theme.errBg : (n.tone == .warn ? Theme.warnBg : Theme.accentSoft)
        return Card(padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: n.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(fg)
                    .frame(width: 36, height: 36)
                    .background(bg, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(n.title).font(.app(.subheadline, .bold)).foregroundStyle(Theme.ink)
                    Text(n.detail).font(.app(.footnote)).foregroundStyle(Theme.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button(n.action, action: n.go)
                .buttonStyle(n.id == "match" ? AnyButtonStyle(PrimaryButtonStyle()) : AnyButtonStyle(SecondaryButtonStyle()))
        }
    }

    // MARK: Helpers

    private var greeting: String {
        state.firstName.isEmpty ? "Welcome to UPT" : "Hi, \(state.firstName)"
    }

    private var arrivalText: String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                                   to: Calendar.current.startOfDay(for: state.profile.arrival)).day ?? 0
        let date = state.profile.arrival.formatted(.dateTime.day().month(.wide))
        if days > 1 { return "\(days) days until you arrive (\(date))" }
        if days == 1 { return "You arrive tomorrow" }
        if days == 0 { return "Welcome to Timișoara, today’s your arrival day" }
        return "Arrived \(date) · Faculty of Automation and Computing"
    }

    private func dueDate(_ task: PaperworkTask) -> Date? {
        guard let n = task.dueWorkdays else { return nil }
        var d = state.profile.arrival
        var left = n
        let cal = Calendar.current
        while left > 0 {
            d = cal.date(byAdding: .day, value: 1, to: d) ?? d
            if !cal.isDateInWeekend(d) { left -= 1 }
        }
        return d
    }
}
