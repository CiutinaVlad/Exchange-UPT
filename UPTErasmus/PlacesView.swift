import SwiftUI
import MapKit
import CoreLocation

/// Looks up building addresses with Apple's geocoder (no coordinates are hard-coded) and caches them.
@MainActor
final class BuildingLocations: ObservableObject {
    static let shared = BuildingLocations()
    @Published private(set) var coordinates: [String: CLLocationCoordinate2D] = [:]
    @Published private(set) var loading = false
    private var started = false

    init() {
        if let saved = UserDefaults.standard.dictionary(forKey: "buildingCoords") as? [String: [Double]] {
            for (k, v) in saved where v.count == 2 {
                coordinates[k] = CLLocationCoordinate2D(latitude: v[0], longitude: v[1])
            }
        }
    }

    func load() async {
        guard !started else { return }
        started = true
        let missing = Buildings.all.filter { $0.geocodeQuery != nil && coordinates[$0.id] == nil }
        guard !missing.isEmpty else { return }
        loading = true
        let geocoder = CLGeocoder()
        for b in missing {
            guard let q = b.geocodeQuery else { continue }
            if let place = try? await geocoder.geocodeAddressString(q).first, let loc = place.location {
                coordinates[b.id] = loc.coordinate
            }
            try? await Task.sleep(nanoseconds: 300_000_000)   // be gentle with the geocoder
        }
        loading = false
        let dict = coordinates.mapValues { [$0.latitude, $0.longitude] }
        UserDefaults.standard.set(dict, forKey: "buildingCoords")
    }
}

struct PlacesView: View {
    @EnvironmentObject var state: AppState
    @ObservedObject private var locations = BuildingLocations.shared
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedBuilding: String? = nil
    @State private var roomQuery = ""
    private let tt = Timetable.shared

    var body: some View {
        let byBuilding = classesByBuilding()
        ScreenScroll {
            VStack(alignment: .leading, spacing: 4) {
                Text("First weeks").font(.app(.largeTitle, .bold)).foregroundStyle(Theme.ink)
                Text("Who to ask, where each building is, and every phone number you need.").font(.app(.subheadline)).foregroundStyle(Theme.sub)
            }

            if state.selected.isEmpty {
                Button { state.coursesSection = .match; state.tab = .courses } label: {
                    Label("Add your courses to see where your classes are", systemImage: "mappin.and.ellipse")
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            SectionTitle(title: "Who to ask", subtitle: "Offices, secretariats and phone numbers · tap to call or email")
            ForEach(Offices.all) { o in
                Card {
                    Text(o.name).font(.app(.subheadline, .semibold)).foregroundStyle(Theme.ink)
                    VStack(alignment: .leading, spacing: 3) {
                        Label(o.location, systemImage: "mappin.and.ellipse").font(.app(.caption)).foregroundStyle(Theme.sub)
                        if !o.hours.isEmpty { Label(o.hours, systemImage: "clock").font(.app(.caption)).foregroundStyle(Theme.sub) }
                    }
                    ContactLinks(contact: o.contact)
                    HStack {
                        ChipTag(text: o.source)
                        Spacer()
                        MapsLink(address: o.address)
                    }
                }
            }

            SectionTitle(title: "Buildings and rooms", subtitle: nil)
            VStack(alignment: .leading, spacing: 0) {
                Map(position: $position, selection: $selectedBuilding) {
                    ForEach(Buildings.all) { b in
                        if let c = locations.coordinates[b.id] {
                            let count = byBuilding[b.id]?.count ?? 0
                            Marker(b.name, systemImage: count > 0 ? "graduationcap.fill" : "building.2", coordinate: c)
                                .tint(count > 0 ? Theme.accent : Theme.faint)
                                .tag(b.id)
                        }
                    }
                }
                .frame(height: 280)
                HStack(spacing: 8) {
                    if locations.loading { ProgressView() }
                    Text(mapCaption).font(.app(.caption)).foregroundStyle(Theme.sub)
                    Spacer()
                    if selectedBuilding != nil {
                        Button("Show all") { selectedBuilding = nil }.font(.app(.caption, .semibold))
                    }
                }
                .padding(12)
                .background(Theme.panel)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))

            Card(padding: 16) {
                FieldLabel(text: "WHERE IS MY ROOM?")
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.faint)
                    TextField("Room code, e.g. B426, P14, 304CP", text: $roomQuery)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Theme.ground, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                if !roomQuery.trimmingCharacters(in: .whitespaces).isEmpty { roomResult(roomQuery) }
            }

            SectionTitle(title: "All faculty buildings", subtitle: "Where your AC classes can be")
            Card(padding: 0) {
                ForEach(Array(Buildings.all.enumerated()), id: \.element.id) { i, b in
                    if i > 0 { Divider().overlay(Theme.line).padding(.leading, 14) }
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(b.name).font(.app(.subheadline, .semibold)).foregroundStyle(Theme.ink)
                            Text(b.address).font(.app(.caption)).foregroundStyle(Theme.sub)
                            if !b.detail.isEmpty { Text(b.detail).font(.app(.caption)).foregroundStyle(Theme.faint) }
                        }
                        Spacer(minLength: 8)
                        if b.geocodeQuery != nil { MapsLink(address: b.address) }
                    }
                    .padding(14)
                }
            }

            SectionTitle(title: "Your classes by building", subtitle: state.selected.isEmpty ? nil : "Tap a class to see its details.")
            if state.selected.isEmpty {
                Text("Your classes will appear here once you add courses.").font(.app(.subheadline)).foregroundStyle(Theme.sub)
            } else {
                ForEach(buildingOrder(byBuilding), id: \.self) { id in
                    if selectedBuilding == nil || selectedBuilding == id {
                        buildingCard(id: id, sessions: byBuilding[id] ?? [])
                    }
                }
            }

        }
        .navigationTitle("First weeks")
        .navigationBarTitleDisplayMode(.inline)
        .task { await locations.load() }
    }

    private var mapCaption: String {
        if locations.loading { return "Finding buildings on the map…" }
        if locations.coordinates.isEmpty { return "The map needs internet the first time, to look up building addresses." }
        return "Teal pins: buildings with your classes. Tap a pin."
    }

    private func classesByBuilding() -> [String: [Session]] {
        var out: [String: [Session]] = [:]
        for s in state.plan.items {
            let id = Buildings.of(room: s.room)?.id ?? "unknown"
            out[id, default: []].append(s)
        }
        return out.mapValues { $0.sorted { ($0.day, $0.start) < ($1.day, $1.start) } }
    }

    private func buildingOrder(_ dict: [String: [Session]]) -> [String] {
        dict.keys.sorted { (dict[$0]?.count ?? 0) > (dict[$1]?.count ?? 0) }
    }

    private func buildingCard(id: String, sessions: [Session]) -> some View {
        let b = Buildings.byID(id)
        return Card(padding: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(b?.name ?? "Room not in the legend yet").font(.app(.headline)).foregroundStyle(Theme.ink)
                    if let b = b { Text(b.address).font(.app(.caption)).foregroundStyle(Theme.sub) }
                }
                Spacer()
                ChipTag(text: "\(sessions.count) class\(sessions.count == 1 ? "" : "es")")
            }
            if let b = b { MapsLink(address: b.address) }
            ForEach(sessions) { s in
                Divider().overlay(Theme.line)
                NavigationLink(value: CourseRoute(code: s.code)) {
                    let c = tt.course(s.code)
                    LinkRow(title: "\(s.timeText) · \(s.type.label)",
                            subtitle: "\(c?.name ?? s.code)\(c?.isRomanian == true ? " 🇷🇴" : "") · room \(s.room.isEmpty ? "not listed" : s.room)")
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func roomResult(_ room: String) -> some View {
        if let b = Buildings.of(room: room) {
            let key = room.uppercased().replacingOccurrences(of: " ", with: "")
            let mine = state.plan.items.filter { $0.room.uppercased().replacingOccurrences(of: " ", with: "").hasPrefix(key) }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(room.uppercased()).font(.app(.headline)).foregroundStyle(Theme.ink)
                    Image(systemName: "arrow.right").font(.app(.caption)).foregroundStyle(Theme.faint)
                    Text(b.name).font(.app(.subheadline, .semibold)).foregroundStyle(Theme.ink)
                }
                Text(b.address + (Buildings.floor(of: room).map { " · " + $0 } ?? "")).font(.app(.caption)).foregroundStyle(Theme.sub)
                Text(b.detail).font(.app(.caption)).foregroundStyle(Theme.sub)
                if !mine.isEmpty {
                    Text("Your classes here: " + Set(mine.map { $0.code }).sorted().joined(separator: ", ")).font(.app(.caption, .semibold)).foregroundStyle(Theme.ink)
                }
                MapsLink(address: b.address)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 8))
        } else {
            Text("We don't know the building for \"\(room)\" yet. Check maps.upt.ro.").font(.app(.caption)).foregroundStyle(Theme.sub)
        }
    }
}


/// Turns "mail@upt.ro · +40 256 403 014" into tap-to-email and tap-to-call buttons; other text stays text.
struct ContactLinks: View {
    let contact: String
    var body: some View {
        let parts = contact.components(separatedBy: " · ")
        VStack(alignment: .leading, spacing: 6) {
            ForEach(parts, id: \.self) { part in
                let p = part.trimmingCharacters(in: .whitespaces)
                if p.contains("@"), let url = URL(string: "mailto:\(p)") {
                    Link(destination: url) { Label(p, systemImage: "envelope").font(.app(.caption, .semibold)) }
                } else if p.hasPrefix("+"), let url = URL(string: "tel:\(p.filter { $0.isNumber || $0 == "+" })") {
                    Link(destination: url) { Label(p, systemImage: "phone").font(.app(.caption, .semibold)) }
                } else {
                    Label(p, systemImage: "info.circle").font(.app(.caption)).foregroundStyle(Theme.sub)
                }
            }
        }
    }
}
