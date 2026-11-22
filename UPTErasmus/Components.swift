import SwiftUI

// Card-based building blocks, so screens don't look like the Settings app.
// Colours come from Theme (COLOR-GUIDE.md): light ground, white panels, teal only for actions.

/// A scrolling screen on the light ground.
struct ScreenScroll<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) { content }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
        }
        .contentMargins(.bottom, ErasmusTabBar.clearance, for: .scrollContent)  // last items stay above the tab bar
        .background(Theme.ground)
        .scrollDismissesKeyboard(.interactively)
    }
}

/// Title above a group of cards.
struct SectionTitle: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.app(.title3, .bold)).foregroundStyle(Theme.ink)
            if let subtitle = subtitle {
                Text(subtitle).font(.app(.subheadline)).foregroundStyle(Theme.sub)
            }
        }
        .padding(.top, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// White panel with a thin border.
struct Card<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .panelCard(padding: padding)
    }
}

/// Filled teal button: the main action on a screen.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(.body, .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(Theme.accentInk)
            .background(configuration.isPressed ? Theme.accentHover : Theme.accent, in: RoundedRectangle(cornerRadius: 12))
            .opacity(enabled ? 1 : 0.45)
    }
}

/// Outlined teal button: secondary actions.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(.subheadline, .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(Theme.accent)
            .background(configuration.isPressed ? Theme.accentSoft : Theme.panel, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accentSoftLine, lineWidth: 1))
    }
}

/// A labelled text input inside a card.
struct LabeledInput: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.app(.caption, .semibold)).foregroundStyle(Theme.sub)
            TextField(placeholder, text: $text)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Theme.ground, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                .foregroundStyle(Theme.ink)
        }
    }
}

/// Small caption label for controls.
struct FieldLabel: View {
    let text: String
    var body: some View { Text(text).font(.app(.caption, .semibold)).foregroundStyle(Theme.sub) }
}

/// A number with a label, for summaries.
struct StatTile: View {
    let value: String
    let label: String
    var tone: Banner.Kind? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(value).font(.app(.title2, .bold)).foregroundStyle(Theme.ink)
                if tone != nil { Circle().fill(color).frame(width: 8, height: 8).accessibilityHidden(true) }
            }
            Text(label).font(.app(.caption)).foregroundStyle(Theme.sub).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelCard(padding: 12)
    }
    private var color: Color {
        switch tone { case .bad?: return Theme.err; case .good?: return Theme.ok; case .warn?: return Theme.warnLine; default: return Theme.ink }
    }
}

/// A tappable row inside a card: title, optional subtitle, teal chevron.
struct LinkRow: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    var body: some View {
        HStack(spacing: 12) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.app(.body))
                    .foregroundStyle(Theme.sub)
                    .frame(width: 34, height: 34)
                    .background(Theme.chip, in: RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.app(.subheadline, .semibold)).foregroundStyle(Theme.ink)
                if let subtitle = subtitle {
                    Text(subtitle).font(.app(.caption)).foregroundStyle(Theme.sub).multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.app(.caption, .semibold)).foregroundStyle(Theme.accent)
        }
        .contentShape(Rectangle())
    }
}

/// Label + value inside a card.
struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.app(.caption, .semibold)).foregroundStyle(Theme.sub)
            Text(value).font(.app(.subheadline)).foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Round check button used for ticking courses and tasks.
struct CheckCircle: View {
    let on: Bool
    var body: some View {
        Image(systemName: on ? "checkmark.circle.fill" : "circle")
            .font(.app(.title3))
            .foregroundStyle(on ? Theme.accent : Theme.faint)
    }
}

/// "Open in Maps" as a small outlined link.
struct MapsLink: View {
    let address: String
    var body: some View {
        if let url = Buildings.mapsURL(address) {
            Link(destination: url) {
                Label("Open in Maps", systemImage: "map")
                    .font(.app(.caption, .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Theme.panel, in: Capsule())
                    .overlay(Capsule().stroke(Theme.accentSoftLine, lineWidth: 1))
                    .foregroundStyle(Theme.accent)
            }
        }
    }
}


// MARK: - ECTS against the minimum

/// Running ECTS total against the student's minimum. Below the minimum is a warning, never a block:
/// rules differ per home university, so the student sets the minimum.
struct ECTSMeter: View {
    let total: Int
    let unknown: Int
    @Binding var minimum: Int
    /// Credits listed at the home university (Learning Agreement, Table A), when we could read them.
    var homeTotal: Int? = nil

    var body: some View {
        let short = max(minimum - total, 0)
        let ok = short == 0
        Card {
            HStack(alignment: .firstTextBaseline) {
                Text("\(total)").font(.app(size: 30, .bold)).foregroundStyle(Theme.ink)
                Text("of \(minimum) ECTS").font(.app(.subheadline, .semibold)).foregroundStyle(Theme.sub)
                Spacer()
                Text(ok ? "Minimum reached" : "\(short) short")
                    .font(.app(.caption, .semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(ok ? Theme.okBg : Theme.warnBg, in: Capsule())
                    .overlay(Capsule().stroke(ok ? Color.clear : Theme.warnLine, lineWidth: 1))
                    .foregroundStyle(Theme.ink)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.chip)
                    Capsule().fill(ok ? Theme.ok : Theme.warnLine)
                        .frame(width: g.size.width * min(CGFloat(total) / CGFloat(max(minimum, 1)), 1))
                }
            }
            .frame(height: 8)
            if unknown > 0 {
                Text("\(unknown) course\(unknown > 1 ? "s have" : " has") no confirmed ECTS yet, so they're not counted. Check the UPT study plan.")
                    .font(.app(.caption)).foregroundStyle(Theme.sub)
            }
            if let home = homeTotal, home > 0 {
                Text(home == total
                     ? "Matches your home courses: \(home) ECTS in Table A, \(total) ECTS at UPT in Table B."
                     : "Your home courses add up to \(home) ECTS (Table A), UPT courses to \(total) ECTS (Table B). The two totals should match. If they can't, your coordinators note why in the Learning Agreement.")
                    .font(.app(.caption)).foregroundStyle(Theme.sub)
            }
            Stepper(value: $minimum, in: 3...60) {
                Text("Your home university's minimum: **\(minimum) ECTS**").font(.app(.caption)).foregroundStyle(Theme.ink)
            }
        }
    }
}

/// Small tag for a course offered by another faculty.
struct FacultyTag: View {
    let course: Course
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(Theme.faculty(course.faculty)).frame(width: 7, height: 7)
            Text(course.faculty).font(.app(.caption2, .semibold))
        }
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(Theme.chip, in: Capsule())
        .foregroundStyle(Theme.ink)
    }
}

/// ECTS chip: credits from the study plan, or a question mark when not confirmed.
struct ECTSTag: View {
    let course: Course
    var body: some View {
        Text(course.ects.map { "\($0) ECTS" } ?? "ECTS ?")
            .font(.app(.caption2, .semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Theme.chip, in: Capsule())
            .foregroundStyle(course.ects == nil ? Theme.sub : Theme.ink)
    }
}
