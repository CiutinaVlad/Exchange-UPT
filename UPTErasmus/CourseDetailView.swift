import SwiftUI

struct CourseDetailView: View {
    let code: String
    @EnvironmentObject var state: AppState
    private let tt = Timetable.shared

    var body: some View {
        if let c = tt.course(code) {
            content(c)
        } else {
            Text("Course not found.").foregroundStyle(Theme.sub)
        }
    }

    private func content(_ c: Course) -> some View {
        let mine = state.selected.contains(c.code)
        let planItems = state.plan.items.filter { $0.code == c.code }.sorted { ($0.day, $0.start) < ($1.day, $1.start) }
        let clashes = state.plan.clashes.filter { $0.a.code == c.code || $0.b.code == c.code }
        let all = tt.sessions(for: c.code).sorted { ($0.type.sortOrder, $0.day, $0.start) < ($1.type.sortOrder, $1.day, $1.start) }
        let buildings = Array(Set(all.compactMap { Buildings.of(room: $0.room) })).sorted { $0.name < $1.name }
        let equivalent = Matcher.equivalent(of: c)

        return ScreenScroll {
            // Header
            HStack(spacing: 0) {
                Rectangle().fill(Theme.faculty(c.faculty)).frame(width: 4)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        LanguageTag(course: c)
                        YearTag(year: c.year)
                        ECTSTag(course: c)
                        if c.isOtherFaculty { FacultyTag(course: c) }
                    }
                    Text(c.name).font(.app(.title2, .bold)).foregroundStyle(Theme.ink)
                    if c.isRomanian {
                        Text("In English: \(c.englishName) (our translation)").font(.app(.subheadline)).italic().foregroundStyle(Theme.sub)
                    }
                    Text(c.lecturer.isEmpty ? c.programmeName : "\(c.lecturer) · \(c.programmeName)")
                        .font(.app(.caption)).foregroundStyle(Theme.sub)
                }
                .padding(14)
                Spacer(minLength: 0)
            }
            .background(Theme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))


            if c.isOtherFaculty {
                Banner(kind: .info, text: "**Offered by \(c.facultyShort)**, not by Automation & Computing. You can usually take it if both Erasmus coordinators approve it in your Learning Agreement.")
            }
            if c.isRomanian {
                Banner(kind: .warn, text: "🇷🇴 **This course is taught in Romanian.** Check with your coordinator before adding it to your Learning Agreement.")
            }
            if !clashes.isEmpty {
                ForEach(clashes) { k in
                    let other = k.a.code == c.code ? k.b : k.a
                    NavigationLink(value: CourseRoute(code: other.code)) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(Days.short[k.a.day]) \(k.overlap.start):00–\(k.overlap.end):00 · \(Weeks.label(k.overlap.weeks))").font(.app(.subheadline, .semibold))
                            Text("with \(tt.course(other.code)?.name ?? other.code) \(other.type.label.lowercased())").font(.app(.caption))
                        }
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Theme.errBg, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button { state.toggle(c.code) } label: {
                Label(mine ? "Remove from my courses" : "Add to my courses", systemImage: mine ? "minus.circle" : "plus.circle")
            }
            .buttonStyle(mine ? AnyButtonStyle(SecondaryButtonStyle()) : AnyButtonStyle(PrimaryButtonStyle()))

            if let eq = equivalent {
                Card {
                    NavigationLink(value: CourseRoute(code: eq.code)) {
                        LinkRow(title: eq.name,
                                subtitle: c.isRomanian ? "English-taught course with similar content" : "Also taught in Romanian",
                                systemImage: "arrow.triangle.swap")
                    }
                    .buttonStyle(.plain)
                }
            }



            SectionTitle(title: "About")
            Card(padding: 16) {
                InfoRow(label: "Lecturer", value: c.lecturer.isEmpty ? "Not listed in the timetable" : c.lecturer)
                InfoRow(label: "Teaching language", value: c.isRomanian ? "Romanian" : "English")
                InfoRow(label: "Faculty", value: c.facultyName)
                InfoRow(label: "Programme", value: "\(c.programmeName), year \(c.year)")
                InfoRow(label: "Credits", value: c.ects.map { "\($0) ECTS (UPT study plan)" } ?? "Not confirmed yet. Check the UPT study plan or ask your coordinator.")
                HStack(alignment: .firstTextBaseline) {
                    Text("Course code").font(.app(.subheadline)).foregroundStyle(Theme.sub)
                    Spacer()
                    Text(c.displayCode).font(.code(.subheadline)).foregroundStyle(Theme.ink).textSelection(.enabled)
                }
                InfoRow(label: "Contact", value: "Search the lecturer's name in Outlook with your student account. UPT staff emails follow firstname.lastname@upt.ro (Guide p. 11).")
            }

            if !planItems.isEmpty {
                SectionTitle(title: "Your sessions")
                ForEach(planItems) { s in sessionCard(s, highlight: true) }
            }


            if !buildings.isEmpty {
                SectionTitle(title: "Where it happens")
                ForEach(buildings) { b in
                    Card {
                        Text(b.name).font(.app(.subheadline, .semibold)).foregroundStyle(Theme.ink)
                        Text(b.address).font(.app(.caption)).foregroundStyle(Theme.sub)
                        MapsLink(address: b.address)
                    }
                }
            }

            SectionTitle(title: "All sessions this semester", subtitle: "Erasmus students are usually placed in a lab group by the secretariat or the lab teacher.")
            Card(padding: 0) {
                ForEach(Array(all.enumerated()), id: \.element.id) { i, s in
                    if i > 0 { Divider().overlay(Theme.line) }
                    sessionRow(s, highlight: planItems.contains(s)).padding(.horizontal, 14).padding(.vertical, 10)
                }
            }
            Text("Source: AC timetable, Semester I 2026/27.").font(.app(.caption)).foregroundStyle(Theme.faint)
        }
        .navigationTitle(c.code)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sessionCard(_ s: Session, highlight: Bool) -> some View {
        sessionRow(s, highlight: highlight).panelCard(padding: 12)
    }

    private func sessionRow(_ s: Session, highlight: Bool) -> some View {
        let b = Buildings.of(room: s.room)
        return HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Text(Days.short[s.day]).font(.app(.caption, .bold)).foregroundStyle(Theme.ink)
                Text("\(s.start)–\(s.end)").font(.app(.caption2)).foregroundStyle(Theme.sub)
            }
            .frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(s.type.label).font(.app(.subheadline, .semibold)).foregroundStyle(Theme.ink)
                    if highlight {
                        Text("Yours").font(.app(.caption2, .bold)).padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Theme.chip, in: Capsule()).foregroundStyle(Theme.ink)
                    }
                }
                Text("Room \(s.room.isEmpty ? "not listed" : s.room)\(b.map { " · " + $0.name } ?? "")")
                    .font(.app(.caption)).foregroundStyle(Theme.sub)
                Text("\(Weeks.label(Array(s.weekSet))) · \(s.groupsText)").font(.app(.caption)).foregroundStyle(Theme.faint)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Lets a view pick a button style at runtime.
struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) { make = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}
