import SwiftUI

/// Courses tab: your list, matching from your Learning Agreement, and the full catalogue.
struct CoursesView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            Picker("Courses", selection: $state.coursesSection) {
                ForEach(CoursesSection.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.ground)

            switch state.coursesSection {
            case .mine: MyCoursesView()
            case .match: MatchView()
            case .browse: CourseBrowserView()
            }
        }
        .background(Theme.ground)
        .navigationTitle("Courses")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The courses the student has added, with their credits.
struct MyCoursesView: View {
    @EnvironmentObject var state: AppState
    private let tt = Timetable.shared

    var body: some View {
        let courses = state.selected.compactMap { tt.course($0) }.sorted { ($0.year, $0.name) < ($1.year, $1.name) }
        let credits = AppState.ects(of: Array(state.selected))
        ScreenScroll {
            VStack(alignment: .leading, spacing: 4) {
                Text("My courses").font(.app(.largeTitle, .bold)).foregroundStyle(Theme.ink)
                Text("You don’t need them all at once. Add more whenever you’re ready.")
                    .font(.app(.subheadline)).foregroundStyle(Theme.sub)
            }
            if courses.isEmpty {
                Card(padding: 16) {
                    Text("No courses yet").font(.app(.headline)).foregroundStyle(Theme.ink)
                    Text("Upload your Learning Agreement and we’ll match each course, or pick from the catalogue.")
                        .font(.app(.subheadline)).foregroundStyle(Theme.sub)
                    Button("Match my courses") { state.coursesSection = .match }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Browse all courses") { state.coursesSection = .browse }
                        .buttonStyle(SecondaryButtonStyle())
                }
            } else {
                Button { state.tab = .schedule } label: {
                    Label("See my week", systemImage: "calendar")
                }
                .buttonStyle(PrimaryButtonStyle())
                HStack(spacing: 10) {
                    Button("Match more") { state.coursesSection = .match }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("Browse") { state.coursesSection = .browse }
                        .buttonStyle(SecondaryButtonStyle())
                }
                ECTSMeter(total: credits.total, unknown: credits.unknown, minimum: $state.minECTS)
                Card(padding: 0) {
                    ForEach(Array(courses.enumerated()), id: \.element.code) { i, c in
                        if i > 0 { Divider().overlay(Theme.line).padding(.leading, 16) }
                        row(c)
                    }
                }
            }
        }
    }

    private func row(_ c: Course) -> some View {
        HStack(alignment: .center, spacing: 12) {
            NavigationLink(value: CourseRoute(code: c.code)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(c.name).font(.app(.subheadline, .semibold)).foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        YearTag(year: c.year)
                        ECTSTag(course: c)
                        Text(c.displayCode).font(.code(.caption2)).foregroundStyle(Theme.sub).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button { withAnimation { state.toggle(c.code) } } label: {
                Image(systemName: "minus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.err)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(c.name)")
        }
        .padding(.leading, 16).padding(.trailing, 6).padding(.vertical, 8)
    }
}
