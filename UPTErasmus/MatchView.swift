import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct MatchView: View {
    @EnvironmentObject var state: AppState
    @State private var input = ""
    @State private var results: [MatchResult] = []
    @State private var status: (Banner.Kind, String)? = nil
    @State private var reading = false
    @State private var showImporter = false
    @State private var photoItem: PhotosPickerItem? = nil
    @FocusState private var editing: Bool

    private let tt = Timetable.shared

    var body: some View {
        ScreenScroll {
            VStack(alignment: .leading, spacing: 4) {
                Text("Match your courses").font(.app(.largeTitle, .bold)).foregroundStyle(Theme.ink)
                Text("Upload your Learning Agreement or paste your home courses. We match them to the courses UPT offers Erasmus students: taught in English, years 1–4.")
                    .font(.app(.subheadline)).foregroundStyle(Theme.sub)
            }
            if let status = status { Banner(kind: status.0, text: status.1) }

            // Upload
            Card(padding: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.app(.title2)).foregroundStyle(Theme.sub)
                        .frame(width: 46, height: 46)
                        .background(Theme.chip, in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Upload your Learning Agreement").font(.app(.headline)).foregroundStyle(Theme.ink)
                        Text("PDF, Word, text or a photo. Read on your iPhone.").font(.app(.caption)).foregroundStyle(Theme.sub)
                    }
                    Spacer()
                    if reading { ProgressView() }
                }
                HStack(spacing: 10) {
                    Button { showImporter = true } label: { Label("Choose file", systemImage: "doc.badge.arrow.up") }
                        .buttonStyle(SecondaryButtonStyle())
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Photo", systemImage: "camera")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .disabled(reading)   // one document at a time, so two reads can't overwrite each other
            }


            // Course list
            Card(padding: 16) {
                HStack {
                    FieldLabel(text: "YOUR COURSES · ONE PER LINE")
                    Spacer()
                    Button("Try an example") { input = Matcher.example; results = []; status = nil }
                        .font(.app(.caption, .semibold))
                }
                TextEditor(text: $input)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140)
                    .font(.app(.callout))
                    .foregroundStyle(Theme.ink)
                    .padding(6)
                    .background(Theme.ground, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                    .overlay(alignment: .topLeading) {
                        if input.isEmpty {
                            Text("e.g. Parallele Programmierung – 5 ECTS")
                                .font(.app(.callout)).foregroundStyle(Theme.faint)
                                .padding(.top, 14).padding(.leading, 11)
                                .allowsHitTesting(false)
                        }
                    }
                    .focused($editing)
            }

            Button {
                editing = false
                runMatch()
            } label: {
                Label("Match with UPT courses", systemImage: "sparkle.magnifyingglass")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(reading || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if !results.isEmpty { resultsSection }

            SectionTitle(title: "Or pick courses yourself")
            Card {
                Button { state.coursesSection = .browse } label: {
                    LinkRow(title: "Browse all \(tt.courses.count) Erasmus courses", subtitle: "Automation & Computing, taught in English, years 1–4", systemImage: "books.vertical")
                }
                .buttonStyle(.plain)
                if !state.selected.isEmpty {
                    Divider().overlay(Theme.line)
                    Button { state.coursesSection = .mine } label: {
                        LinkRow(title: "\(state.selected.count) courses selected", subtitle: "See my courses", systemImage: "checklist")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: Self.fileTypes) { result in
            if case .success(let url) = result { read(url: url) }
        }
        .onChange(of: photoItem) { _, item in
            if let item = item { read(photo: item) }
        }
    }

    // MARK: Results

    @ViewBuilder
    private var resultsSection: some View {
        let picked = results.compactMap { $0.code }.compactMap { tt.course($0) }
        let roCount = picked.filter { $0.isRomanian }.count
        let years = Set(picked.map { $0.year })
        SectionTitle(title: "\(results.count) courses matched", subtitle: "Check each match, change it if needed, then add them to your list.")
        if roCount > 0 {
            Banner(kind: .warn, text: "🇷🇴 **\(roCount) of your matches \(roCount > 1 ? "are" : "is") only taught in Romanian.** Check with your coordinator, or switch to an English alternative where one is shown.")
        }
        if years.count > 1 {
            Banner(kind: .info, text: "Your courses come from **\(years.count) different years**. That's normal for Erasmus students. Check your week for clashes.")
        }
        let other = picked.filter { $0.isOtherFaculty }
        if !other.isEmpty {
            Banner(kind: .info, text: "**\(other.count) match\(other.count > 1 ? "es are" : " is") at another faculty** (\(Set(other.map { $0.facultyShort }).sorted().joined(separator: ", "))). Erasmus students can usually take courses from other faculties if both coordinators approve them in the Learning Agreement. Confirm with the UPT International Office, and check the walk between buildings.")
        }
        Button {
            state.add(results.filter { $0.include }.compactMap { $0.code })
            state.coursesSection = .mine
        } label: {
            Label("Add \(results.filter { $0.include && $0.code != nil }.count) courses to my list", systemImage: "plus.circle")
        }
        .buttonStyle(PrimaryButtonStyle())
        let included = results.filter { $0.include }
        let credits = AppState.ects(of: included.compactMap { $0.code })
        ECTSMeter(total: credits.total, unknown: credits.unknown, minimum: $state.minECTS,
                  homeTotal: Self.homeECTS(included.map { $0.home }))
        ForEach($results) { $r in
            MatchCard(result: $r)
        }

        Text("Courses, codes and ECTS come from UPT’s official Erasmus course catalogue 2026–2027. Check them with your coordinator before you sign your Learning Agreement.")
            .font(.app(.caption)).foregroundStyle(Theme.sub)
    }

    /// ECTS written on the student's own course lines ("Datenbanken – 5 ECTS"), as in Table A.
    static func homeECTS(_ lines: [String]) -> Int? {
        let values = lines.compactMap { line -> Int? in
            guard let r = line.range(of: "(\\d{1,2})\\s*(ECTS|CP|credits?)", options: [.regularExpression, .caseInsensitive]) else { return nil }
            return Int(line[r].prefix { $0.isNumber })
        }
        return values.count == lines.count && !values.isEmpty ? values.reduce(0, +) : nil
    }

    private func runMatch() {
        let lines = input.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        results = Matcher.match(lines: lines, allowRomanian: state.profile.canStudyInRomanian)
    }

    // MARK: Reading files and photos

    static let fileTypes: [UTType] = {
        var t: [UTType] = [.pdf, .plainText, .commaSeparatedText, .image]
        if let docx = UTType(filenameExtension: "docx") { t.append(docx) }
        if let doc = UTType(filenameExtension: "doc") { t.append(doc) }
        return t
    }()

    private func read(url: URL) {
        let name = url.lastPathComponent
        reading = true
        status = (.info, "Reading **\(name)**…")
        Task {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let text = try await Task.detached(priority: .userInitiated) { try DocumentReader.text(from: url) }.value
                finish(text: text, source: name)
            } catch {
                reading = false
                status = (.bad, error.localizedDescription + " You can type your courses instead.")
            }
        }
    }

    private func read(photo item: PhotosPickerItem) {
        reading = true
        status = (.info, "Reading your photo…")
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self), let img = UIImage(data: data) else {
                    throw DocumentReader.ReadError.empty
                }
                let text = try await Task.detached(priority: .userInitiated) { try DocumentReader.recognizeText(in: img) }.value
                finish(text: text, source: "your photo")
            } catch {
                reading = false
                status = (.bad, "We couldn't read that photo. Try a sharper photo, or upload a PDF.")
            }
            photoItem = nil
        }
    }

    private func finish(text: String, source: String) {
        reading = false
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            status = (.warn, "We couldn't find any text in \(source). If it's a scan, try a photo of it instead.")
            return
        }
        let isLA = !DocumentReader.learningAgreementCourses(text).isEmpty
        let courses = DocumentReader.guessCourses(text)
        guard !courses.isEmpty else {
            status = (.warn, "We couldn't find course names in \(source). Type them in the box instead.")
            return
        }
        input = courses.joined(separator: "\n")
        status = (.good, "Found **\(courses.count) course\(courses.count > 1 ? "s" : "")** in \(source)\(isLA ? " (Learning Agreement, Table A)" : ""). Matching them now. Check the list below.")
        runMatch()
    }
}

// MARK: - One matched course

struct MatchCard: View {
    @Binding var result: MatchResult
    private let tt = Timetable.shared

    var body: some View {
        let course = result.code.flatMap { tt.course($0) }
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Button { result.include.toggle() } label: { CheckCircle(on: result.include && course != nil) }
                    .buttonStyle(.plain)
                    .disabled(course == nil)
                VStack(alignment: .leading, spacing: 2) {
                    Text("YOUR COURSE").font(.app(.caption2, .semibold)).foregroundStyle(Theme.faint)
                    Text(result.home).font(.app(.subheadline, .semibold)).foregroundStyle(Theme.ink)
                }
                Spacer()
                Text(confidenceText).font(.app(.caption2, .semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(confidenceBg, in: Capsule())
                    .foregroundStyle(confidenceInk)
            }

            HStack(spacing: 0) {
                Rectangle().fill(course.map { Theme.faculty($0.faculty) } ?? Theme.line).frame(width: 3)
                VStack(alignment: .leading, spacing: 6) {
                    Text("UPT COURSE").font(.app(.caption2, .semibold)).foregroundStyle(Theme.faint)
                    Picker("UPT course", selection: $result.code) {
                        Text("No match").tag(String?.none)
                        ForEach(tt.courses) { c in
                            Text("\(c.name) (year \(c.year))").tag(String?.some(c.code))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize(horizontal: false, vertical: true)

                    if let c = course {
                        HStack(spacing: 6) {
                            LanguageTag(course: c, compact: c.isOtherFaculty)
                            YearTag(year: c.year)
                            ECTSTag(course: c)
                            if c.isOtherFaculty { FacultyTag(course: c) }
                            Spacer()
                            Text(c.displayCode).font(.code(.caption2)).foregroundStyle(Theme.sub).lineLimit(1)
                            NavigationLink(value: CourseRoute(code: c.code)) {
                                Text("Details").font(.app(.caption, .semibold))
                            }
                        }
                    }
                }
                .padding(10)
                Spacer(minLength: 0)
            }
            .background(Theme.ground, in: RoundedRectangle(cornerRadius: 8))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if let alt = result.alternative, let a = tt.course(alt), alt != result.code {
                Button {
                    result.code = alt
                    result.include = true
                } label: {
                    Label("Use the \(a.isRomanian ? "Romanian 🇷🇴" : "English") version: \(a.name)", systemImage: "arrow.triangle.swap")
                        .font(.app(.caption, .semibold))
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.borderless)
            }
        }
        .panelCard(padding: 14)
        // Picking a course by hand includes it; choosing "No match" leaves it out.
        .onChange(of: result.code) { _, new in result.include = new != nil }
    }

    private var confidenceText: String {
        switch result.confidence { case .high: return "Good match"; case .medium: return "Possible"; case .low: return "No match" }
    }
    private var confidenceBg: Color {
        switch result.confidence { case .high: return Theme.okBg; case .medium: return Theme.warnBg; case .low: return Theme.errBg }
    }
    private var confidenceInk: Color {
        Theme.ink   // status colour stays in the background only
    }
}

// MARK: - Browse all courses

struct CourseBrowserView: View {
    @EnvironmentObject var state: AppState
    @State private var filter = "all"
    @State private var appliedDefault = false
    @State private var query = ""
    private let tt = Timetable.shared

    var body: some View {
        ScreenScroll {
            ForEach(1...4, id: \.self) { year in
                let list = courses(year)
                if !list.isEmpty {
                    SectionTitle(title: "Year \(year)", subtitle: "\(list.count) courses")
                    ForEach(list) { c in courseCard(c) }
                }
            }
            if (1...4).allSatisfy({ courses($0).isEmpty }) {
                Text("No courses match.").font(.app(.subheadline)).foregroundStyle(Theme.sub)
            }
        }
        .searchable(text: $query, prompt: "Search courses or codes")
        // Only the first time: coming back from a course page must not undo the filter the student chose.
        .onAppear {
            guard !appliedDefault else { return }
            appliedDefault = true

        }
        .safeAreaInset(edge: .top) {
            if !state.selected.isEmpty {
                Button { state.coursesSection = .mine } label: {
                    Text("\(state.selected.count) selected · see my courses")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Theme.ground.opacity(0.95))
            }
        }
    }

    private func courseCard(_ c: Course) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button { state.toggle(c.code) } label: { CheckCircle(on: state.selected.contains(c.code)) }
                .buttonStyle(.plain)
            NavigationLink(value: CourseRoute(code: c.code)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(c.name).font(.app(.subheadline, .semibold)).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                    if c.isRomanian { Text(c.englishName).font(.app(.caption)).italic().foregroundStyle(Theme.sub).multilineTextAlignment(.leading) }
                    HStack(spacing: 6) {
                        LanguageTag(course: c, compact: true)
                        ECTSTag(course: c)
                        if c.isOtherFaculty { FacultyTag(course: c) }
                        if !c.lecturer.isEmpty { Text(c.lecturer).font(.app(.caption2)).foregroundStyle(Theme.sub) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Image(systemName: "chevron.right").font(.app(.caption, .semibold)).foregroundStyle(Theme.accent).padding(.top, 4)
        }
        .panelCard(padding: 12)
    }

    private func courses(_ year: Int) -> [Course] {
        tt.courses.filter { c in
            c.year == year
            && (filter == "all" || c.language.rawValue == filter)
            && (query.isEmpty || c.name.localizedCaseInsensitiveContains(query) || c.englishName.localizedCaseInsensitiveContains(query) || c.code.localizedCaseInsensitiveContains(query) || c.officialCode.localizedCaseInsensitiveContains(query))
        }
    }
}
