import Foundation

// MARK: - Courses and sessions (real AC + ETC timetables, Semester I 2026/27)

enum TeachingLanguage: String {
    case english = "EN"
    case romanian = "RO"
}

struct Course: Identifiable, Hashable {
    let code: String
    let name: String
    let year: Int
    let lecturer: String
    let language: TeachingLanguage
    let programme: String      // "C-EN", "C", "TI" or "C/TI"
    let englishName: String    // our translation, Romanian courses only
    let faculty: String        // "AC" or "ETC"
    let ects: Int?             // from the UPT Erasmus course catalogue; nil when not published
    let officialCode: String   // catalogue code such as L002.25.03.F1 ("" when not listed)
    /// The code students see on official documents, or our short code if the catalogue has none.
    var displayCode: String { officialCode.isEmpty ? code : officialCode }

    var id: String { code }
    var isRomanian: Bool { language == .romanian }
    /// The English name: the course name itself, or our translation for Romanian courses.
    var nameInEnglish: String { isRomanian ? englishName : name }

    /// Offered by another faculty than Automation and Computing.
    var isOtherFaculty: Bool { faculty != "AC" }
    var facultyShort: String { faculty == "ETC" ? "Electronics & Telecom" : "Automation & Computing" }
    var facultyName: String {
        faculty == "ETC" ? "Faculty of Electronics, Telecommunications and Information Technologies (ETcTI)"
                         : "Faculty of Automation and Computing (AC)"
    }
    var ectsText: String { ects.map { "\($0) ECTS" } ?? "ECTS not confirmed" }

    var programmeName: String {
        switch programme {
        case "TST-EN": return "Telecommunications Technologies and Systems (English)"
        case "C-EN": return "Computers (English)"
        case "C": return "Calculatoare (Romanian)"
        case "TI": return "Tehnologia Informației (Romanian)"
        default: return "Calculatoare and Tehnologia Informației (Romanian)"
        }
    }
}

enum SessionType: String, CaseIterable {
    case lecture = "c", lab = "l", seminar = "s", project = "p"

    var label: String {
        switch self {
        case .lecture: return "Lecture"
        case .lab: return "Lab"
        case .seminar: return "Seminar"
        case .project: return "Project"
        }
    }
    var sortOrder: Int { SessionType.allCases.firstIndex(of: self) ?? 0 }
}

struct Session: Identifiable, Hashable {
    let id: Int
    let code: String
    let type: SessionType
    let day: Int          // 0 = Monday … 4 = Friday
    let start: Int        // hour
    let end: Int          // hour
    let groups: String    // "*" everyone, "?" pick any slot, or a list such as "1.1,1.2"
    let room: String
    let weeks: String     // "all", "odd", "even" or "1-10"
    let weekSet: Set<Int>

    /// Fixed sessions (lectures, or sessions for everyone) can't be moved.
    var isFixed: Bool { type == .lecture || groups == "*" }
    var timeText: String { "\(Days.short[day]) \(start):00–\(end):00" }
    var groupsText: String {
        switch groups {
        case "*": return "everyone"
        case "?": return "pick any slot"
        default: return "group " + groups
        }
    }
}

enum Days {
    static let short = ["Mon", "Tue", "Wed", "Thu", "Fri"]
}

enum Weeks {
    static let all = Set(1...14)

    static func parse(_ text: String) -> Set<Int> {
        switch text {
        case "all", "": return all
        case "odd": return Set(stride(from: 1, through: 14, by: 2))
        case "even": return Set(stride(from: 2, through: 14, by: 2))
        default:
            let parts = text.split(separator: "-").compactMap { Int($0) }
            if parts.count == 2, parts[0] <= parts[1] { return Set(parts[0]...parts[1]) }
            return all
        }
    }

    static func label(_ weeks: [Int]) -> String {
        let w = weeks.sorted()
        guard let first = w.first, let last = w.last else { return "" }
        if w.count == 14 { return "every week" }
        if w.count == 7 && w.allSatisfy({ $0 % 2 == 1 }) { return "odd weeks" }
        if w.count == 7 && w.allSatisfy({ $0 % 2 == 0 }) { return "even weeks" }
        if last - first + 1 == w.count { return "weeks \(first)–\(last)" }
        return "\(w.count) weeks"
    }
}

// MARK: - Timetable loader (timetable.json is bundled with the app)

final class Timetable {
    static let shared = Timetable()

    let courses: [Course]
    let sessions: [Session]
    let source: String
    private let byCode: [String: Course]

    private init() {
        var courses: [Course] = []
        var sessions: [Session] = []
        var source = ""
        if let url = Bundle.main.url(forResource: "timetable", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            source = root["source"] as? String ?? ""
            for row in root["courses"] as? [[Any]] ?? [] where row.count >= 7 {
                guard let code = row[0] as? String, let name = row[1] as? String,
                      let year = row[2] as? Int else { continue }
                courses.append(Course(
                    code: code, name: name, year: year,
                    lecturer: row[3] as? String ?? "",
                    language: TeachingLanguage(rawValue: row[4] as? String ?? "EN") ?? .english,
                    programme: row[5] as? String ?? "C-EN",
                    englishName: row[6] as? String ?? "",
                    faculty: row.count > 7 ? (row[7] as? String ?? "AC") : "AC",
                    ects: row.count > 8 ? row[8] as? Int : nil,
                    officialCode: row.count > 9 ? (row[9] as? String ?? "") : ""))
            }
            for (i, row) in (root["sessions"] as? [[Any]] ?? []).enumerated() where row.count >= 8 {
                guard let code = row[0] as? String, let t = row[1] as? String,
                      let type = SessionType(rawValue: t),
                      let day = row[2] as? Int, let s = row[3] as? Int, let e = row[4] as? Int else { continue }
                let weeks = row[7] as? String ?? "all"
                sessions.append(Session(id: i, code: code, type: type, day: day, start: s, end: e,
                                        groups: row[5] as? String ?? "*", room: row[6] as? String ?? "",
                                        weeks: weeks, weekSet: Weeks.parse(weeks)))
            }
        }
        self.courses = courses
        self.sessions = sessions
        self.source = source
        self.byCode = Dictionary(courses.map { ($0.code, $0) }, uniquingKeysWith: { a, _ in a })
    }

    func course(_ code: String) -> Course? { byCode[code] }
    func sessions(for code: String) -> [Session] { sessions.filter { $0.code == code } }
}

// MARK: - Buildings (from the timetable's room legend, "Legenda sali")

struct Building: Identifiable, Hashable {
    let id: String
    let name: String
    let address: String
    let detail: String
    /// Address used to find the building on the map. Nil when the legend gives no street address.
    let geocodeQuery: String?
}

enum Buildings {
    static let all: [Building] = [
        Building(id: "electro", name: "Electro building", address: "Bd. Vasile Pârvan 2, Timișoara",
                 detail: "Rooms A…, B…, C… and D1. The first digit after the letter is the floor. The AC dean's office is in wing A.",
                 geocodeQuery: "Bulevardul Vasile Pârvan 2, Timișoara, Romania"),
        Building(id: "aspc", name: "ASPC building", address: "Str. Ioan Curea 1, Timișoara",
                 detail: "Lecture room ASPC and labs S4, P14, P17, all on the ground floor.",
                 geocodeQuery: "Strada Ioan Curea 1, Timișoara, Romania"),
        Building(id: "cadastru", name: "MP – Cadastru building", address: "Str. Ioan Curea, Timișoara",
                 detail: "Between ASPC and the Faculty of Civil Engineering.",
                 geocodeQuery: nil),
        Building(id: "chimieParc", name: "Chimie Parc (new Chemistry building)", address: "Bd. Vasile Pârvan 6, Timișoara",
                 detail: "Rooms 301CP, 303CP, 304CP.",
                 geocodeQuery: "Bulevardul Vasile Pârvan 6, Timișoara, Romania"),
        Building(id: "chimieOld", name: "Chemistry faculty, old building", address: "Bd. Vasile Pârvan 6, Timișoara",
                 detail: "Rooms A2 – Chimie and A3 – Chimie.",
                 geocodeQuery: nil),
        Building(id: "mec", name: "Faculty of Mechanical Engineering", address: "Bd. Mihai Viteazu 1, Timișoara",
                 detail: "Room M304.",
                 geocodeQuery: "Bulevardul Mihai Viteazu 1, Timișoara, Romania"),
        Building(id: "orologerie", name: "Orologerie (Mechanical Engineering)", address: "Bd. Mihai Viteazu 1, Timișoara",
                 detail: "Department of Mechanics and Strength of Materials.",
                 geocodeQuery: nil),
        Building(id: "spm", name: "SPM building", address: "Opposite dorm 2MV, Timișoara",
                 detail: "Rooms SPM 202, SPM 205 (written \"SMP205\" in the timetable) and SPM 223.",
                 geocodeQuery: nil),
        Building(id: "mecNoua", name: "New Mechanical building (Mecanica Nouă)", address: "Faculty of Mechanical Engineering, Timișoara (exact address to confirm)",
                 detail: "Rooms starting with N (N = nouă, new), e.g. N303. Rooms starting with M are in the old Mechanical building.",
                 geocodeQuery: nil),
        Building(id: "mpt", name: "Faculty of Management in Production and Transportation", address: "Str. Remus 14, Timișoara",
                 detail: "Room M102 and the amphitheatres A0 and A1.",
                 geocodeQuery: "Strada Remus 14, Timișoara, Romania"),
    ]

    static func byID(_ id: String) -> Building? { all.first { $0.id == id } }

    /// Which building a timetable room code is in.
    static func of(room: String) -> Building? {
        let r = room.uppercased().trimmingCharacters(in: .whitespaces)
        guard !r.isEmpty else { return nil }
        func has(_ pattern: String) -> Bool { r.range(of: pattern, options: .regularExpression) != nil }
        if has("ASPC") || has("^(S4|P14|P17)\\b") { return byID("aspc") }
        if has("\\d{3}CP\\b") { return byID("chimieParc") }
        if has("CHIMIE") { return byID("chimieOld") }
        if has("CADASTRU") { return byID("cadastru") }
        if has("OROL") { return byID("orologerie") }
        if has("^N\\d{3}") { return byID("mecNoua") }
        if has("MEC|^M\\d{3}") { return byID("mec") }
        if has("SMP|SPM") { return byID("spm") }
        if has("MPT|M102") { return byID("mpt") }
        if has("^[ABC]\\d{3}[A-Z]?\\b") || r == "D1" { return byID("electro") }
        return nil
    }

    /// Wing and floor for rooms in the Electro building, e.g. "B426" → wing B, floor 4.
    static func floor(of room: String) -> String? {
        let r = room.uppercased()
        guard let m = r.range(of: "^[ABC]\\d{3}", options: .regularExpression) else { return nil }
        let code = Array(r[m])
        return "wing \(code[0]), floor \(code[1])"
    }

    static func mapsURL(_ address: String) -> URL? {
        var c = URLComponents(string: "http://maps.apple.com/")
        c?.queryItems = [URLQueryItem(name: "q", value: address)]
        return c?.url
    }
}

// MARK: - Offices (UPT International Students' Guide 2026–2027)

struct Office: Identifiable {
    let id = UUID()
    let name: String
    let location: String
    let hours: String
    let contact: String
    let address: String
    let source: String
}

enum Offices {
    static let all: [Office] = [
        Office(name: "International Students Office", location: "Rectorate, Piața Victoriei 2, 1st floor, room 107",
               hours: "Mon–Thu 12:00–15:30 · Fri 11:00–13:00", contact: "student-admissions@upt.ro · +40 256 403 014",
               address: "Piața Victoriei 2, Timișoara", source: "Guide p. 9"),
        Office(name: "Student certificate pick-up", location: "Rectorate, room 110",
               hours: "Tue and Thu 12:00–14:00", contact: "Request online first",
               address: "Piața Victoriei 2, Timișoara", source: "Guide p. 10"),
        Office(name: "AC Secretariat (Bachelor's)", location: "Bd. Vasile Pârvan 2, ground floor, room A5 (Master's: 1st floor, A107a)",
               hours: "Mon–Thu 13:00–15:00 · Fri 11:00–13:00", contact: "secretariat@ac.upt.ro · +40 256 403 211",
               address: "Bd. Vasile Pârvan 2, Timișoara", source: "Guide p. 14"),
        Office(name: "Students' Health Polyclinic", location: "Aleea Studenților 1, Students Campus",
               hours: "Appointments Mon–Fri 10:00–14:00, only on your faculty's days", contact: "+40 771 500 926",
               address: "Aleea Studenților 1, Timișoara", source: "Guide p. 19"),
        Office(name: "UPT Library", location: "Bd. Vasile Pârvan 4/A · 24/7 study room at the back",
               hours: "Mon–Thu 9:00–20:00 · Fri 9:00–18:00 (term time)", contact: "bupt@upt.ro",
               address: "Bd. Vasile Pârvan 4A, Timișoara", source: "Guide p. 25–26"),
        Office(name: "Students Campus (dorms)", location: "Complexul Studențesc",
               hours: "", contact: "From the airport: bus E4 to Bastion, then a short taxi or walk",
               address: "Complexul Studentesc, Timișoara", source: "Guide p. 6"),
    ]
}
