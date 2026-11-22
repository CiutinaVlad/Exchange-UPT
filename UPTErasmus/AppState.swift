import Foundation
import SwiftUI
import CryptoKit

struct Profile: Codable, Equatable {
    var name = ""
    var country = ""
    var homeUniversity = ""
    var level = "Bachelor"
    var canStudyInRomanian = false
    var arrival = defaultArrivalDate
    var isEU = true
}

/// Default arrival: 28 Sept 2026 (start of the guide's arrival week). File-level constant, so it isn't tied to the main actor.
let defaultArrivalDate: Date = {
    var c = DateComponents(); c.year = 2026; c.month = 9; c.day = 28; c.hour = 12
    return Calendar(identifier: .gregorian).date(from: c) ?? Date()
}()

/// The five tabs, left to right. Home sits in the middle.
enum AppTab: Hashable { case courses, schedule, home, resources, firstWeeks }

/// The three views of the Courses tab.
enum CoursesSection: String, CaseIterable, Identifiable {
    case mine = "My courses", match = "Match", browse = "All courses"
    var id: String { rawValue }
}

/// A local account (demo only: stored on this iPhone, nothing is sent anywhere).
struct Account: Codable {
    var name: String
    var passwordHash: String
}

/// A class detail page, opened from the schedule, the map or the course lists.
struct CourseRoute: Hashable { let code: String }

@MainActor
final class AppState: ObservableObject {
    static var defaultArrival: Date { defaultArrivalDate }

    // MARK: Account
    /// Signed-in account's email, nil = show the landing page.
    @Published private(set) var currentEmail: String?
    private var accounts: [String: Account]

    // MARK: The signed-in student's data (saved per account)
    @Published var profile: Profile { didSet { save() } }
    @Published var selected: Set<String> { didSet { save(); scheduleRebuild() } }
    @Published var locks: [String: Int] { didSet { save(); scheduleRebuild() } }
    @Published var done: Set<String> { didSet { save() } }
    /// Group per year/programme key (see `Groups`), picked by the student. Missing key = automatic.
    @Published var groups: [String: String] { didSet { save(); scheduleRebuild() } }
    /// Minimum ECTS the student's home university requires this semester (usually 30).
    @Published var minECTS: Int { didSet { save() } }

    // MARK: Navigation
    @Published var tab: AppTab = .home
    @Published var coursesSection: CoursesSection = .match
    @Published var showProfile = false
    /// Changes on sign-in, sign-out and reset, so every screen starts fresh.
    @Published private(set) var session = UUID()
    @Published private(set) var plan: Plan = .empty

    private let store = UserDefaults.standard
    private var loading = false

    init() {
        let d = UserDefaults.standard
        accounts = (d.data(forKey: "accounts")).flatMap { try? JSONDecoder().decode([String: Account].self, from: $0) } ?? [:]
        profile = Profile(); selected = []; locks = [:]; done = []; groups = [:]; minECTS = 30
        if let email = d.string(forKey: "currentEmail"), accounts[email] != nil {
            currentEmail = email
            load(email)
        }
    }

    // MARK: Sign up / in / out

    enum AuthError: LocalizedError {
        case name, email, password, exists, wrong
        var errorDescription: String? {
            switch self {
            case .name: return "Enter your name."
            case .email: return "Enter a valid email address."
            case .password: return "Use at least 6 characters for your password."
            case .exists: return "An account with this email already exists on this iPhone. Log in instead."
            case .wrong: return "Email or password is not right."
            }
        }
    }

    static func normalise(_ email: String) -> String { email.trimmingCharacters(in: .whitespaces).lowercased() }
    static func isValidEmail(_ e: String) -> Bool { e.range(of: "^[^@\\s]+@[^@\\s]+\\.[^@\\s]{2,}$", options: .regularExpression) != nil }

    private static func hash(_ password: String, salt: String) -> String {
        SHA256.hash(data: Data((salt + "|" + password).utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func register(name: String, email rawEmail: String, password: String, isEU: Bool) throws {
        let email = Self.normalise(rawEmail)
        let name = name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { throw AuthError.name }
        guard Self.isValidEmail(email) else { throw AuthError.email }
        guard password.count >= 6 else { throw AuthError.password }
        guard accounts[email] == nil else { throw AuthError.exists }
        accounts[email] = Account(name: name, passwordHash: Self.hash(password, salt: email))
        persistAccounts()
        signIn(email)
        profile.name = name
        profile.isEU = isEU
        tab = .home
    }

    func login(email rawEmail: String, password: String) throws {
        let email = Self.normalise(rawEmail)
        guard let acct = accounts[email], acct.passwordHash == Self.hash(password, salt: email) else { throw AuthError.wrong }
        signIn(email)
    }

    func logout() {
        save()
        currentEmail = nil
        store.removeObject(forKey: "currentEmail")
        clearMemory()
    }

    /// Deletes the signed-in account and everything saved for it on this iPhone.
    func deleteAccount() {
        guard let email = currentEmail else { return }
        for k in ["profile", "selected", "locks", "done", "groups", "minECTS"] { store.removeObject(forKey: key(k, email)) }
        accounts[email] = nil
        persistAccounts()
        currentEmail = nil
        store.removeObject(forKey: "currentEmail")
        clearMemory()
    }

    /// A fresh test account for debug builds: tester1@example.com, tester2@… (example.com is reserved for examples).
    func nextTestEmail() -> String {
        var n = 1
        while accounts["tester\(n)@example.com"] != nil { n += 1 }
        return "tester\(n)@example.com"
    }
    var lastTestEmail: String? {
        accounts.keys.filter { $0.hasPrefix("tester") && $0.hasSuffix("@example.com") }.sorted {
            (Int($0.dropFirst(6).prefix { $0.isNumber }) ?? 0) < (Int($1.dropFirst(6).prefix { $0.isNumber }) ?? 0)
        }.last
    }
    static let testPassword = "erasmus123"

    private func signIn(_ email: String) {
        currentEmail = email
        store.set(email, forKey: "currentEmail")
        load(email)
    }

    private func persistAccounts() {
        if let data = try? JSONEncoder().encode(accounts) { store.set(data, forKey: "accounts") }
    }

    private func key(_ name: String, _ email: String) -> String { "u.\(email).\(name)" }

    private func load(_ email: String) {
        loading = true
        let d = store
        profile = (d.data(forKey: key("profile", email))).flatMap { try? JSONDecoder().decode(Profile.self, from: $0) } ?? Profile()
        selected = Set(d.stringArray(forKey: key("selected", email)) ?? [])
        locks = (d.dictionary(forKey: key("locks", email)) as? [String: Int]) ?? [:]
        done = Set(d.stringArray(forKey: key("done", email)) ?? [])
        groups = (d.dictionary(forKey: key("groups", email)) as? [String: String]) ?? [:]
        minECTS = d.object(forKey: key("minECTS", email)) as? Int ?? 30
        loading = false
        tab = .home
        coursesSection = selected.isEmpty ? .match : .mine
        session = UUID()
        rebuild()
    }

    private func clearMemory() {
        loading = true
        profile = Profile(); selected = []; locks = [:]; done = []; groups = [:]; minECTS = 30
        loading = false
        tab = .home
        showProfile = false
        session = UUID()
        plan = .empty
    }

    private func save() {
        guard !loading, let email = currentEmail else { return }
        if let data = try? JSONEncoder().encode(profile) { store.set(data, forKey: key("profile", email)) }
        store.set(Array(selected), forKey: key("selected", email))
        store.set(locks, forKey: key("locks", email))
        store.set(Array(done), forKey: key("done", email))
        store.set(groups, forKey: key("groups", email))
        store.set(minECTS, forKey: key("minECTS", email))
    }
    private func rebuild() {
        plan = Scheduler.build(selected: selected, locks: locks, groups: groups)
    }

    /// Several changes in one tap (course + its locks) rebuild the week once, not once per change.
    private var rebuildPending = false
    private func scheduleRebuild() {
        guard !rebuildPending else { return }
        rebuildPending = true
        Task { @MainActor in
            self.rebuildPending = false
            self.rebuild()
        }
    }

    /// Adds or removes one course. Slots the student picked by hand for other courses are kept.
    func toggle(_ code: String) {
        if selected.contains(code) {
            selected.remove(code)
            locks = locks.filter { !$0.key.hasPrefix(code + "|") }
        } else {
            selected.insert(code)
        }
    }

    /// Adds courses (pressing it twice changes nothing). Hand-picked slots are kept.
    func add(_ codes: [String]) {
        let new = Set(codes).subtracting(selected)
        guard !new.isEmpty else { return }
        selected.formUnion(new)
    }

    /// Clears this student's courses, lab groups and checklist but keeps the account and name.
    func reset() {
        profile = Profile(name: profile.name, isEU: profile.isEU)
        selected = []
        locks = [:]
        done = []
        groups = [:]
        minECTS = 30
        tab = .home
        coursesSection = .match
        session = UUID()
    }

    /// Puts the student in one group for a year (nil = automatic). Hand-picked slots of that year are dropped,
    /// so every lab and seminar of the year follows the new group.
    func setGroup(_ key: String, to sub: String?) {
        let year = Int(key.split(separator: "|").first ?? "") ?? -1
        locks = locks.filter { entry in
            let code = String(entry.key.split(separator: "|").first ?? "")
            return Timetable.shared.course(code)?.year != year
        }
        groups[key] = sub
    }

    func fillDemo() {
        profile = Profile(name: "Lukas Weber", country: "Germany", homeUniversity: "Technical University (sample)",
                          level: "Bachelor", canStudyInRomanian: false, arrival: AppState.defaultArrival, isEU: true)
    }

    /// Credits of the given UPT courses: the known total and how many courses have no confirmed ECTS yet.
    static func ects(of codes: [String]) -> (total: Int, unknown: Int) {
        let courses = Set(codes).compactMap { Timetable.shared.course($0) }
        return (courses.compactMap { $0.ects }.reduce(0, +), courses.filter { $0.ects == nil }.count)
    }

    var firstName: String { profile.name.split(separator: " ").first.map(String.init) ?? "" }
}
