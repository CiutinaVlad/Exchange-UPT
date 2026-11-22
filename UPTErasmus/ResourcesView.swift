import SwiftUI

/// What EU and non-EU students need. Every item comes from UPT's International Students' Guide 2026–2027
/// (page in the chip); where the guide doesn't cover Erasmus students, it says "check with your coordinator".
struct ResourcesView: View {
    @EnvironmentObject var state: AppState
    @State private var showEU: Bool? = nil
    @State private var topic: Topic = .stay
    @State private var open: Set<String> = []

    private enum Topic: String, CaseIterable, Identifiable {
        case stay = "Stay & health", bring = "What to bring", firstDays = "First days"
        var id: String { rawValue }
        var icon: String {
            switch self { case .stay: return "checkmark.shield"; case .bring: return "bag"; case .firstDays: return "calendar.badge.clock" }
        }
    }

    private struct Item: Identifiable {
        var id: String { title }
        let icon: String
        let title: String
        let detail: String
        let source: String
    }

    var body: some View {
        let eu = showEU ?? state.profile.isEU
        ScreenScroll {
            VStack(alignment: .leading, spacing: 4) {
                Text("Resources").font(.app(.largeTitle, .bold)).foregroundStyle(Theme.ink)
                Text("What you need for your stay, depending on your citizenship.").font(.app(.subheadline)).foregroundStyle(Theme.sub)
            }

            Picker("Citizenship", selection: Binding(get: { eu }, set: { showEU = $0 })) {
                Text("EU citizens").tag(true)
                Text("Non-EU citizens").tag(false)
            }
            .pickerStyle(.segmented)

            if eu != state.profile.isEU {
                Text("You’re registered as \(state.profile.isEU ? "an EU" : "a non-EU") citizen. Showing the other list for reference.")
                    .font(.app(.caption)).foregroundStyle(Theme.sub)
            }

            // Topic filter: one short list at a time
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Topic.allCases) { t in
                        let on = topic == t
                        Button { withAnimation(.snappy) { topic = t } } label: {
                            Label(t.rawValue, systemImage: t.icon)
                                .font(.app(.subheadline, on ? .semibold : .medium))
                                .padding(.horizontal, 14).frame(minHeight: 40)
                                .foregroundStyle(on ? Theme.accentInk : Theme.ink)
                                .background(on ? Theme.accent : Theme.panel, in: Capsule())
                                .overlay(Capsule().stroke(on ? Color.clear : Theme.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }

            list(topic == .stay ? (eu ? euStay : nonEUStay) : topic == .bring ? bring : atUPT)

            Text("From UPT’s International Students’ Guide 2026–2027, written mainly for full-degree students. Where it says “check with your coordinator”, the Erasmus process may differ.")
                .font(.app(.caption)).foregroundStyle(Theme.faint)
        }
        .navigationTitle("Resources")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Content

    private var euStay: [Item] { [
        Item(icon: "cross.case", title: "European Health Insurance Card (EHIC)",
             detail: "Bring your EHIC from your home country.", source: "Guide"),
        Item(icon: "house", title: "Registration of your stay",
             detail: "For stays over 3 months: check with your coordinator whether you need a registration certificate.", source: "Guide p. 22–23"),
        Item(icon: "doc.badge.clock", title: "Student Certificate",
             detail: "Request it online, then pick it up in room 110 (Tue and Thu 12:00–14:00). Takes up to 10 working days. Needed for the bank and the polyclinic.", source: "Guide p. 10"),
    ] }

    private var nonEUStay: [Item] { [
        Item(icon: "person.text.rectangle", title: "Visa",
             detail: "Check what you need with your coordinator before you travel.", source: "Check with your coordinator"),
        Item(icon: "building.columns", title: "Residence permit at IGI Timiș",
             detail: "Book well ahead, at least 30 days before your visa expires. UPT books Tuesday slots.", source: "Guide p. 22–23"),
        Item(icon: "cross.case", title: "Health insurance",
             detail: "Part of the residence permit steps: see the guide, and check with your coordinator which insurance is accepted.", source: "Guide p. 22–23"),
        Item(icon: "doc.badge.clock", title: "Student Certificate",
             detail: "Request it online, then pick it up in room 110 (Tue and Thu 12:00–14:00). Takes up to 10 working days. Needed for the residence permit, the bank and the polyclinic.", source: "Guide p. 10"),
    ] }

    private var bring: [Item] { [
        Item(icon: "doc.on.doc", title: "Passport, 4 passport photos, copies",
             detail: "Copies of the documents you uploaded when you applied.", source: "Guide p. 10"),
        Item(icon: "banknote", title: "Cash for the dorm: about 700 lei",
             detail: "600 lei of it is a deposit, refunded if the room is undamaged.", source: "Guide p. 6, 32"),
        Item(icon: "signature", title: "Learning Agreement",
             detail: "Signed by you, your home university and UPT. Check for clashes on the Schedule tab before you sign.", source: "Check with your coordinator"),
    ] }

    private var atUPT: [Item] { [
        Item(icon: "simcard", title: "Romanian phone number",
             detail: "Needed to activate your student email and to join the WhatsApp groups.", source: "Guide p. 5"),
        Item(icon: "person.badge.plus", title: "Enrol at the International Students Office",
             detail: "Rectorate, Piața Victoriei 2, room 107 · Mon–Thu 12:00–15:30, Fri 11:00–13:00. Erasmus students may enrol through the International Relations office: check with your coordinator.", source: "Guide p. 9"),
        Item(icon: "pencil.and.list.clipboard", title: "Study Contract at the AC Secretariat",
             detail: "Within 5 working days of enrolling. Room A5, Bd. Vasile Pârvan 2 · Mon–Thu 13:00–15:00, Fri 11:00–13:00.", source: "Guide p. 10, 14"),
        Item(icon: "envelope", title: "Student email",
             detail: "firstname.lastname@student.upt.ro. Login details arrive by SMS after the Study Contract; first login at mail.upt.ro.", source: "Guide p. 11"),
        Item(icon: "books.vertical", title: "Library card",
             detail: "Bring your student record book from the secretariat. Opens the library, the 24/7 study room and sports facilities.", source: "Guide p. 25"),
    ] }

    // MARK: Layout

    /// Short rows: the title only; tap to read the details and the source.
    private func list(_ items: [Item]) -> some View {
        Card(padding: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                if i > 0 { Divider().overlay(Theme.line).padding(.leading, 60) }
                let expanded = open.contains(item.id)
                Button {
                    withAnimation(.snappy) { if expanded { open.remove(item.id) } else { open.insert(item.id) } }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.accentSoftInk)
                            .frame(width: 34, height: 34)
                            .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 9))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title).font(.app(.subheadline, .semibold)).foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.leading)
                            if expanded {
                                Text(item.detail).font(.app(.footnote)).foregroundStyle(Theme.sub)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                ChipTag(text: item.source)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.faint)
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                            .padding(.top, 10)
                    }
                    .padding(14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(expanded ? "Hide details" : "Show details")
            }
        }
    }
}
