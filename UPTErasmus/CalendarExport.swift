import SwiftUI
import UIKit

/// Turns the student's week into an iCalendar (.ics) file: every class as a weekly event for the semester.
/// Apple Calendar imports it and can save it into a Google calendar added on the iPhone, so it shows up in Google Calendar.
enum CalendarExport {
    /// Semester I 2026/27 starts on Monday 28 September 2026 (UPT). Teaching week n begins `start + (n-1) weeks`.
    /// The winter break isn't taken into account yet: confirm the faculty's calendar and add those weeks to `breakWeeks`.
    static let semesterStart: DateComponents = DateComponents(year: 2026, month: 9, day: 28)
    static let breakWeeks: Set<Int> = []   // calendar weeks (counted from the start) with no classes

    static func file(for items: [Session], studentName: String) -> URL? {
        let tt = Timetable.shared
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Bucharest") ?? .current
        guard let start = cal.date(from: semesterStart) else { return nil }

        func stamp(_ date: Date, hour: Int) -> String {
            let c = cal.dateComponents([.year, .month, .day], from: date)
            return String(format: "%04d%02d%02dT%02d0000", c.year ?? 0, c.month ?? 0, c.day ?? 0, hour)
        }
        func escape(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: ";", with: "\\;")
             .replacingOccurrences(of: ",", with: "\\,").replacingOccurrences(of: "\n", with: "\\n")
        }
        /// Teaching week → the date of that weekday, skipping break weeks.
        func date(week: Int, day: Int) -> Date? {
            var calendarWeek = 0, teaching = 0
            while teaching < week {
                calendarWeek += 1
                if !breakWeeks.contains(calendarWeek) { teaching += 1 }
                if calendarWeek > 30 { return nil }
            }
            return cal.date(byAdding: .day, value: (calendarWeek - 1) * 7 + day, to: start)
        }

        let nowStamp: String = {
            let f = DateFormatter(); f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"; f.timeZone = TimeZone(identifier: "UTC")
            return f.string(from: Date())
        }()

        var lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Exchange@UPT//Schedule//EN", "CALSCALE:GREGORIAN",
                     "METHOD:PUBLISH", "X-WR-CALNAME:UPT classes – \(escape(studentName.isEmpty ? "Exchange" : studentName))",
                     "X-WR-TIMEZONE:Europe/Bucharest",
                     "BEGIN:VTIMEZONE", "TZID:Europe/Bucharest",
                     "BEGIN:DAYLIGHT", "TZOFFSETFROM:+0200", "TZOFFSETTO:+0300", "TZNAME:EEST", "DTSTART:19700329T030000",
                     "RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU", "END:DAYLIGHT",
                     "BEGIN:STANDARD", "TZOFFSETFROM:+0300", "TZOFFSETTO:+0200", "TZNAME:EET", "DTSTART:19701025T040000",
                     "RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU", "END:STANDARD",
                     "END:VTIMEZONE"]

        for s in items {
            let course = tt.course(s.code)
            let title = "\(course?.name ?? s.code) · \(s.type.label)" + (s.groups == "*" || s.groups == "?" ? "" : " (\(s.groupsText))")
            var location = s.room
            if let b = Buildings.of(room: s.room) { location += location.isEmpty ? b.address : ", \(b.name), \(b.address)" }
            let notes = [course?.displayCode, course?.lecturer, course?.ects.map { "\($0) ECTS" }].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
            let weeks = s.weekSet.sorted()
            guard let first = weeks.first else { continue }

            // One repeating event when the weeks are evenly spaced (every week, odd, even, a range), otherwise one per week.
            let step = weeks.count > 1 ? weeks[1] - weeks[0] : 1
            let regular = weeks.count > 1 && zip(weeks, weeks.dropFirst()).allSatisfy { $1 - $0 == step } && breakWeeks.isEmpty
            let groups: [[Int]] = regular ? [weeks] : weeks.map { [$0] }
            for (gi, g) in groups.enumerated() {
                guard let d = date(week: g[0], day: s.day) else { continue }
                lines += ["BEGIN:VEVENT",
                          "UID:\(s.id)-\(first)-\(gi)@erasmus-upt",
                          "DTSTAMP:\(nowStamp)",
                          "DTSTART;TZID=Europe/Bucharest:\(stamp(d, hour: s.start))",
                          "DTEND;TZID=Europe/Bucharest:\(stamp(d, hour: s.end))",
                          "SUMMARY:\(escape(title))"]
                if g.count > 1 { lines.append("RRULE:FREQ=WEEKLY;INTERVAL=\(step);COUNT=\(g.count)") }
                if !location.isEmpty { lines.append("LOCATION:\(escape(location))") }
                if !notes.isEmpty { lines.append("DESCRIPTION:\(escape(notes))") }
                lines.append("END:VEVENT")
            }
        }
        lines.append("END:VCALENDAR")

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("UPT-classes-Semester-I.ics")
        do {
            try lines.joined(separator: "\r\n").write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch { return nil }
    }
}

/// The iOS share sheet, for handing the .ics file to Calendar, Files, Mail…
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

/// "Add to Google Calendar": one slim white button, like a sign-in-with button.
/// Uses the image set "GoogleCalendar" from Assets if it's there (add Google's official icon); otherwise a calendar symbol.
struct AddToCalendarButton: View {
    @EnvironmentObject var state: AppState
    @State private var file: SharedFile?

    struct SharedFile: Identifiable { let url: URL; var id: String { url.absoluteString } }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                if let url = CalendarExport.file(for: state.plan.items, studentName: state.profile.name) { file = SharedFile(url: url) }
            } label: {
                HStack(spacing: 10) {
                    icon.frame(width: 22, height: 22).accessibilityHidden(true)
                    Text("Add to Google Calendar").font(.app(.subheadline, .semibold)).foregroundStyle(Color(white: 0.15))  // white button in light and dark mode
                }
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(Color.white, in: Capsule())
                .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
                .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Exports your week. In the share sheet choose Calendar, then your Google calendar.")
            Text("Weeks count from 28 Sep 2026 · winter break not excluded yet")
                .font(.app(.caption2)).foregroundStyle(Theme.faint)
                .frame(maxWidth: .infinity)
        }
        .sheet(item: $file) { f in
            ShareSheet(items: [f.url]).presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder private var icon: some View {
        if UIImage(named: "GoogleCalendar") != nil {
            Image("GoogleCalendar").resizable().scaledToFit()
        } else {
            Image(systemName: "calendar.badge.plus").font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.accent)
        }
    }
}
