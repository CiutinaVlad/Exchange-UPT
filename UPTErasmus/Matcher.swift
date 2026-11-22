import Foundation

struct MatchResult: Identifiable {
    let id = UUID()
    let home: String
    var code: String?          // chosen UPT course
    let alternative: String?   // best course in the other teaching language
    let confidence: Confidence
    var include: Bool

    enum Confidence: String { case high, medium, low }
}

/// Offline matcher: compares course names word by word, with rare words weighted higher (TF-IDF cosine).
/// German course names are mapped to English with a small synonym list.
enum Matcher {
    private static let synonyms: [String: String] = [
        "bild": "image", "bildverarbeitung": "image processing", "parallele": "parallel",
        "programmierung": "programming", "algorithmen": "algorithms", "datenstrukturen": "data structures",
        "objektorientierte": "object oriented", "softwarearchitektur": "software systems design",
        "simulation": "simulation modelling", "datenbanken": "databases", "rechnerarchitektur": "computer architecture",
        "netze": "networks", "rechnernetze": "computer networks", "betriebssysteme": "operating systems",
        "verteilte": "distributed", "künstliche": "artificial", "künstlichen": "artificial", "künstlicher": "artificial", "intelligenz": "intelligence",
        "mathematik": "calculus algebra", "webentwicklung": "web application", "mobile": "mobile",
        "architecture": "design systems",
        "grundlagen": "fundamentals", "mustererkennung": "pattern recognition", "softwareverifikation": "software verification",
        "validierung": "validation", "verifikation": "verification", "bioinformatik": "bioinformatics",
        "funktionelle": "functional", "genomik": "genomics", "informatik": "computer",
        "datenbank": "databases", "netzwerke": "networks", "mikroprozessoren": "microprocessor", "robotik": "robotics",
        "mensch": "human", "interaktion": "interaction", "webanwendungen": "web application", "nebenläufige": "concurrent",
        "signale": "signals", "systeme": "systems", "signalverarbeitung": "signals systems", "digitale": "digital",
        "schaltungen": "circuits", "schaltkreise": "integrated circuits", "integrierte": "integrated", "elektronik": "electronic",
        "messtechnik": "measurements", "elektrotechnik": "electrical engineering", "nachrichtentechnik": "telecommunications",
    ]
    private static let stopwords: Set<String> = ["and", "of", "the", "und", "der", "die", "das", "ects", "in", "for", "si", "de", "a"]

    static func tokens(_ text: String) -> Set<String> {
        var s = text.replacingOccurrences(of: "software\\s*-?\\s*archite\\w*", with: "software systems design",
                                          options: [.regularExpression, .caseInsensitive])
        s = s.lowercased()
        let separators = CharacterSet(charactersIn: "–—-()/,.:;").union(.whitespacesAndNewlines)
        var out: [String] = []
        for w in s.components(separatedBy: separators) where !w.isEmpty {
            if w.first?.isNumber == true || stopwords.contains(w) { continue }
            out.append(w)
            if let syn = synonyms[w] { out += syn.split(separator: " ").map(String.init) }
        }
        return Set(out.map(stem))
    }

    private static func stem(_ w: String) -> String {
        if w.hasSuffix("ing") && w.count > 5 { return String(w.dropLast(3)) }
        if w.hasSuffix("s") && w.count > 3 { return String(w.dropLast()) }
        return w
    }

    private static let index: (tokens: [Set<String>], df: [String: Int]) = {
        let toks = Timetable.shared.courses.map { Matcher.tokens($0.name + " " + $0.englishName) }
        var df: [String: Int] = [:]
        for t in toks { for w in t { df[w, default: 0] += 1 } }
        return (toks, df)
    }()

    private static func idf(_ t: String) -> Double {
        let n = Double(Timetable.shared.courses.count + 1)
        return log(n / (Double(index.df[t] ?? 0) + 0.5))
    }

    private static func best(_ a: Set<String>, where keep: (Course) -> Bool) -> (Course?, Double) {
        let na = sqrt(a.reduce(0.0) { $0 + pow(idf($1), 2) })
        var bestCourse: Course? = nil, bestScore = 0.0, bestRank = 0.0
        for (i, c) in Timetable.shared.courses.enumerated() where keep(c) {
            let b = index.tokens[i]
            let dot = b.intersection(a).reduce(0.0) { $0 + pow(idf($1), 2) }
            let nb = sqrt(b.reduce(0.0) { $0 + pow(idf($1), 2) })
            let score = (na * nb) > 0 ? dot / (na * nb) : 0
            // Near-ties go to the home faculty (AC). Another faculty wins only when it is clearly closer.
            let rank = score + (c.isOtherFaculty ? 0 : 0.05)
            if score > 0 && rank > bestRank { bestRank = rank; bestScore = score; bestCourse = c }
        }
        return (bestCourse, bestScore)
    }

    static func match(lines: [String], allowRomanian: Bool) -> [MatchResult] {
        let threshold = 0.25
        return lines.map { line in
            let a = tokens(line)
            let en = best(a) { !$0.isRomanian }
            let ro = best(a) { $0.isRomanian }
            var main = en, alt = ro
            if allowRomanian {
                if ro.1 > en.1 { main = ro; alt = en }
            } else if en.1 < threshold {
                main = ro; alt = en
            }
            let ok = main.1 >= threshold
            let conf: MatchResult.Confidence = main.1 >= 0.5 ? .high : (ok ? .medium : .low)
            return MatchResult(home: line,
                               code: ok ? main.0?.code : nil,
                               alternative: (ok && alt.1 >= 0.45) ? alt.0?.code : nil,
                               confidence: conf,
                               include: ok)
        }
    }

    /// A course with similar content in the other teaching language, if one exists.
    static func equivalent(of course: Course) -> Course? {
        let r = best(tokens(course.nameInEnglish)) { $0.language != course.language && $0.code != course.code }
        return r.1 >= 0.5 ? r.0 : nil
    }

    static let example = """
    Bildverarbeitung (Image Processing) – 6 ECTS
    Parallele Programmierung (Parallel Programming) – 5 ECTS
    Softwarearchitektur (Software Architecture) – 5 ECTS
    Simulation technischer Systeme (Simulation) – 5 ECTS
    Algorithmen und Datenstrukturen – 6 ECTS
    Objektorientierte Programmierung – 5 ECTS
    """
}
