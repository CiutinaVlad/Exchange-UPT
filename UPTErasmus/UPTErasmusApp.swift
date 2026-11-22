import SwiftUI

@main
struct UPTErasmusApp: App {
    @StateObject private var state = AppState()

    init() { AppFont.register() }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .tint(Theme.accent)
        }
    }
}

/// Signed out: landing page. Signed in: the five tabs.
struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Group {
            if state.currentEmail == nil {
                LandingView()
            } else {
                MainView()
            }
        }
        .id(state.session)   // sign-in, sign-out and reset rebuild every screen from scratch
        .font(.app(.body))   // default face for any text without its own font
    }
}

struct MainView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        // All five tabs stay alive (scroll position, typed text, open pages); only the selected one shows.
        ZStack {
            tab(.courses) { CoursesView() }
            tab(.schedule) { ScheduleView() }
            tab(.home) { HomeView() }
            tab(.resources) { ResourcesView() }
            tab(.firstWeeks) { PlacesView() }
        }
        .overlay(alignment: .bottom) { ErasmusTabBar(selection: $state.tab) }
        .sheet(isPresented: $state.showProfile) {
            NavigationStack { ProfileView().shellNavigationBar() }
                .environmentObject(state)
        }
    }

    private func tab<V: View>(_ t: AppTab, @ViewBuilder _ content: () -> V) -> some View {
        let on = state.tab == t
        return NavigationStack { content().erasmusScreen() }
            .opacity(on ? 1 : 0)
            .allowsHitTesting(on)
            .accessibilityHidden(!on)
    }
}

/// The tab bar: four tabs on a slim rail, Home raised and larger in the middle.
struct ErasmusTabBar: View {
    @Binding var selection: AppTab
    /// Space scroll screens leave at the bottom so nothing ends up behind the bar.
    static let clearance: CGFloat = 96

    private let left: [(AppTab, String, String)] = [(.courses, "Courses", "books.vertical"), (.schedule, "Schedule", "calendar")]
    private let right: [(AppTab, String, String)] = [(.resources, "Resources", "doc.text"), (.firstWeeks, "First weeks", "mappin.and.ellipse")]

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                ForEach(left, id: \.1) { item(tab: $0.0, title: $0.1, icon: $0.2) }
                Spacer().frame(width: 76)
                ForEach(right, id: \.1) { item(tab: $0.0, title: $0.1, icon: $0.2) }
            }
            .padding(.horizontal, 6)
            .frame(height: 58)
            .background(Theme.panel, in: Capsule())
            .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)

            homeButton.offset(y: -14)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 4)
        .background(Theme.ground.ignoresSafeArea(edges: .bottom))
    }

    private func item(tab: AppTab, title: String, icon: String) -> some View {
        let on = selection == tab
        return Button { selection = tab } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 18, weight: on ? .semibold : .regular))
                Text(title).font(.app(size: 10, on ? .semibold : .medium)).lineLimit(1).minimumScaleFactor(0.8)
                Capsule().fill(on ? Theme.accent : Color.clear).frame(width: 16, height: 3)
            }
            .foregroundStyle(on ? Theme.accent : Theme.sub)
            .frame(maxWidth: .infinity, minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var homeButton: some View {
        let on = selection == .home
        return Button { selection = .home } label: {
            Image(systemName: on ? "house.fill" : "house")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(on ? Theme.accentInk : Theme.accent)
                .frame(width: 64, height: 64)
                .background(on ? Theme.accent : Theme.panel, in: Circle())
                .overlay(Circle().stroke(on ? Color.clear : Theme.accent, lineWidth: 1.5))
                .shadow(color: Theme.accent.opacity(on ? 0.35 : 0.12), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Home")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

extension View {
    /// Every tab: charcoal top bar with the profile button, and it can open a class detail page.
    func erasmusScreen() -> some View {
        self.shellNavigationBar()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { ProfileButton() }
            }
            .navigationDestination(for: CourseRoute.self) { route in
                CourseDetailView(code: route.code)
                    .shellNavigationBar()
            }
    }
}

/// Top-right person icon on every tab: opens your personal details.
struct ProfileButton: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        Button { state.showProfile = true } label: {
            Text(initials)
                .font(.app(size: 13, .bold))
                .foregroundStyle(Theme.shell)
                .frame(width: 32, height: 32)
                .background(Theme.brandMark, in: Circle())
        }
        .accessibilityLabel("Your profile and personal details")
    }
    private var initials: String { Self.initials(state.profile.name) }
    static func initials(_ name: String) -> String {
        let s = name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
        return s.isEmpty ? "?" : s
    }
}

// MARK: - Shared UI pieces

/// Teaching language. English uses the "ok" status style; Romanian uses "warn", like "English unconfirmed".
struct LanguageTag: View {
    let course: Course
    var compact = false

    var body: some View {
        Text(course.isRomanian ? (compact ? "🇷🇴 RO" : "🇷🇴 Taught in Romanian") : (compact ? "EN" : "Taught in English"))
            .font(.app(.caption2, .semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Theme.chip, in: Capsule())
            .overlay(Capsule().stroke(course.isRomanian ? Theme.warnLine : Color.clear, lineWidth: 1))
            .foregroundStyle(Theme.ink)
    }
}

/// Neutral chip: the guide allows no extra hues for years.
struct YearTag: View {
    let year: Int
    var body: some View { ChipTag(text: "Year \(year)") }
}

/// Faculty dot (AC orange for every course in this prototype).
struct FacultyDot: View {
    var faculty = "AC"
    var size: CGFloat = 10
    var body: some View {
        Circle().fill(Theme.faculty(faculty)).frame(width: size, height: size)
            .accessibilityLabel(faculty == "ETC" ? "Faculty of Electronics and Telecommunications" : "Faculty of Automation and Computing")
    }
}

struct Banner: View {
    enum Kind { case info, good, warn, bad }
    let kind: Kind
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(ink)
                .accessibilityHidden(true)
            Text(.init(text))
                .font(.app(.subheadline))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
            .padding(12)
            .background(background, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(border, lineWidth: 1))
    }
    private var background: Color {
        switch kind { case .info: return Theme.accentSoft; case .good: return Theme.okBg; case .warn: return Theme.warnBg; case .bad: return Theme.errBg }
    }
    private var icon: String {
        switch kind { case .info: return "info.circle.fill"; case .good: return "checkmark.circle.fill"; case .warn: return "exclamationmark.circle.fill"; case .bad: return "exclamationmark.triangle.fill" }
    }
    private var ink: Color {
        switch kind { case .info: return Theme.accentSoftInk; case .good: return Theme.okInk; case .warn: return Theme.warnInk; case .bad: return Theme.err }
    }
    private var border: Color {
        switch kind { case .info: return Theme.accentSoftLine; case .good: return Theme.okBg; case .warn: return Theme.warnLine; case .bad: return Theme.errBg }
    }
}
