import SwiftUI

struct PaperworkTask: Identifiable {
    let id: String
    let title: String
    let detail: String
    let dueWorkdays: Int?   // deadline in working days after arrival
}

struct PaperworkPhase: Identifiable {
    let id: String
    let title: String
    let tasks: [PaperworkTask]
}

struct PaperworkView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let phases = Self.phases(nonEU: !state.profile.isEU)
        let allTasks = phases.flatMap { $0.tasks }
        let total = allTasks.count
        let doneCount = allTasks.filter { state.done.contains($0.id) }.count
        let next = allTasks.first { !state.done.contains($0.id) && $0.dueWorkdays != nil }
        ScreenScroll {
            VStack(alignment: .leading, spacing: 4) {
                Text("Paperwork").font(.app(.largeTitle, .bold)).foregroundStyle(Theme.ink)
                Text("Every step in order, with where to go and when.").font(.app(.subheadline)).foregroundStyle(Theme.sub)
            }

            Banner(kind: .warn, text: "Office details come from UPT's *International Students' Guide 2026–2027*, written mainly for full-degree students. Steps marked **check with your coordinator** may work differently for Erasmus students.")

            Card(padding: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(doneCount) of \(total)").font(.app(.title, .bold)).foregroundStyle(Theme.ink)
                    Text("steps done").font(.app(.subheadline)).foregroundStyle(Theme.sub)
                    Spacer()
                }
                ProgressView(value: Double(doneCount), total: Double(max(total, 1)))
                    .tint(Theme.accent)
                if let next = next, let due = dueDate(next) {
                    Divider().overlay(Theme.line)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NEXT DEADLINE").font(.app(.caption2, .semibold)).foregroundStyle(Theme.faint)
                        Text(next.title).font(.app(.subheadline, .semibold)).foregroundStyle(Theme.ink)
                        Text("by \(due.formatted(.dateTime.weekday(.wide).day().month(.wide)))").font(.app(.caption, .semibold)).foregroundStyle(Theme.sub)
                    }
                }
            }


            ForEach(phases) { phase in
                let phaseDone = phase.tasks.filter { state.done.contains($0.id) }.count
                SectionTitle(title: phase.title, subtitle: "\(phaseDone) of \(phase.tasks.count) done")
                Card(padding: 0) {
                    ForEach(Array(phase.tasks.enumerated()), id: \.element.id) { i, task in
                        if i > 0 { Divider().overlay(Theme.line).padding(.leading, 52) }
                        TaskRow(task: task, done: state.done.contains(task.id), due: dueDate(task)) {
                            if state.done.contains(task.id) { state.done.remove(task.id) } else { state.done.insert(task.id) }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                    }
                }
            }
        }
        .navigationTitle("Paperwork")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dueDate(_ task: PaperworkTask) -> Date? {
        guard let n = task.dueWorkdays else { return nil }
        var d = state.profile.arrival
        var added = 0
        let cal = Calendar(identifier: .gregorian)
        while added < n {
            d = cal.date(byAdding: .day, value: 1, to: d) ?? d
            let wd = cal.component(.weekday, from: d)
            if wd != 1 && wd != 7 { added += 1 }
        }
        return d
    }

    static func phases(nonEU: Bool) -> [PaperworkPhase] {
        [
            PaperworkPhase(id: "before", title: "Before you arrive", tasks: [
                PaperworkTask(id: "la", title: "Learning Agreement signed by you, your home university and UPT",
                              detail: "Use course matching to check for clashes before you sign. Check with your coordinator.", dueWorkdays: nil),
                PaperworkTask(id: "ins", title: "Health insurance",
                              detail: "EU students: bring your EHIC card. Non-EU students: see the residence permit steps.", dueWorkdays: nil),
                PaperworkTask(id: "house", title: "Accommodation booked",
                              detail: "A dorm place or a private rental with a written contract. Never pay a deposit before a viewing.", dueWorkdays: nil),
                PaperworkTask(id: "docs", title: "Documents ready: passport, 4 passport photos, copies of what you uploaded when you applied",
                              detail: "Guide p. 10", dueWorkdays: nil),
                PaperworkTask(id: "cash", title: "Cash for the dorm: about 700 lei (600 lei deposit, refunded if the room is undamaged)",
                              detail: "Guide p. 6 and 32", dueWorkdays: nil),
            ]),
            PaperworkPhase(id: "first", title: "First days in Timișoara", tasks: [
                PaperworkTask(id: "sim", title: "Get a Romanian phone number",
                              detail: "Needed to activate your student email and to join the WhatsApp groups. Guide p. 5.", dueWorkdays: 1),
                PaperworkTask(id: "enrol", title: "Enrol in person at the International Students Office",
                              detail: "Rectorate, Piața Victoriei 2, room 107 · Mon–Thu 12:00–15:30, Fri 11:00–13:00. Check with your coordinator: Erasmus students may enrol through the International Relations office.", dueWorkdays: 2),
                PaperworkTask(id: "cert", title: "Request your Student Certificate online",
                              detail: "Takes up to 10 working days. Pick it up in room 110, Tue/Thu 12:00–14:00. Needed for the bank, polyclinic and residence permit. Guide p. 10.", dueWorkdays: 2),
                PaperworkTask(id: "contract", title: "Sign the Study Contract at the AC Secretariat",
                              detail: "Within 5 working days of enrolling. Room A5, Bd. Vasile Pârvan 2 · Mon–Thu 13:00–15:00, Fri 11:00–13:00. Guide p. 10, 14.", dueWorkdays: 5),
                PaperworkTask(id: "arrivalcert", title: "Get your Certificate of Arrival signed",
                              detail: "Check with your coordinator which UPT office signs it.", dueWorkdays: 5),
            ]),
            PaperworkPhase(id: "weeks", title: "First weeks", tasks: [
                PaperworkTask(id: "email", title: "Activate your student email (firstname.lastname@student.upt.ro)",
                              detail: "Login details arrive by SMS after you sign the Study Contract. First login at mail.upt.ro. Guide p. 11.", dueWorkdays: nil),
                PaperworkTask(id: "cv", title: "Check you are enrolled on Campus Virtual for every course",
                              detail: "cv.upt.ro. Do this at the start of the semester. Guide p. 12.", dueWorkdays: nil),
                PaperworkTask(id: "changes", title: "Report any course changes to your Learning Agreement",
                              detail: "Check with your coordinator for the deadline.", dueWorkdays: nil),
                PaperworkTask(id: "lib", title: "Get your library card",
                              detail: "Bring your student record book from the secretariat. Gives access to the library, the 24/7 study room and sports facilities. Guide p. 25.", dueWorkdays: nil),
                PaperworkTask(id: "reg", title: "Registration of your stay (stays over 3 months)",
                              detail: nonEU
                                ? "Non-EU: residence permit at IGI Timiș. Book well ahead, at least 30 days before your visa expires. UPT books Tuesday slots. Guide p. 22–23."
                                : "EU citizens: check with your coordinator whether you need a registration certificate.", dueWorkdays: nil),
            ]),
            PaperworkPhase(id: "leave", title: "Before you leave", tasks: [
                PaperworkTask(id: "tor", title: "Transcript of Records requested", detail: "Check with your coordinator.", dueWorkdays: nil),
                PaperworkTask(id: "depart", title: "Certificate of Attendance or departure signed", detail: "Check with your coordinator.", dueWorkdays: nil),
                PaperworkTask(id: "deposit", title: "Dorm room checked and deposit returned",
                              detail: "Report damage you find when you move in, so it isn't charged to you. Guide p. 32.", dueWorkdays: nil),
            ]),
        ]
    }
}

struct TaskRow: View {
    let task: PaperworkTask
    let done: Bool
    let due: Date?
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .top, spacing: 12) {
                CheckCircle(on: done)
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title).font(.app(.subheadline, .semibold))
                        .strikethrough(done)
                        .foregroundStyle(done ? Theme.faint : Theme.ink)
                        .multilineTextAlignment(.leading)
                    if !done {
                        Text(task.detail).font(.app(.caption)).foregroundStyle(Theme.sub).multilineTextAlignment(.leading)
                    }
                    if let due = due, !done {
                        Label("Due \(due.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))", systemImage: "clock")
                            .font(.app(.caption, .semibold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Theme.warnBg, in: Capsule())
                            .foregroundStyle(Theme.ink)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
