import Foundation
import PDFKit
import Vision
import UIKit
import Compression

/// Reads a course document (PDF, Word .docx, text, photo) and picks out the lines that look like courses.
/// Everything runs on the iPhone: PDFKit for PDFs, a small zip reader for .docx, Vision for photos.
enum DocumentReader {
    enum ReadError: LocalizedError {
        case unsupported, empty, oldWord
        var errorDescription: String? {
            switch self {
            case .unsupported: return "We can read PDF, Word (.docx), text files and photos."
            case .empty: return "We couldn't find any text in this file."
            case .oldWord: return "Old Word (.doc) files can't be read. Save it as .docx or PDF and try again."
            }
        }
    }

    static func text(from url: URL) throws -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "txt", "csv", "md", "text":
            return try String(contentsOf: url, encoding: .utf8)
        case "pdf":
            guard let doc = PDFDocument(url: url) else { throw ReadError.empty }
            var pages: [String] = []
            for i in 0..<min(doc.pageCount, 20) {
                if let s = doc.page(at: i)?.string { pages.append(s) }
            }
            return pages.joined(separator: "\n")
        case "docx":
            return try docxText(Data(contentsOf: url))
        case "doc":
            throw ReadError.oldWord
        case "jpg", "jpeg", "png", "heic", "heif":
            guard let img = UIImage(contentsOfFile: url.path) else { throw ReadError.empty }
            return try recognizeText(in: img)
        default:
            throw ReadError.unsupported
        }
    }

    // MARK: Photos (Vision, on device)

    static func recognizeText(in image: UIImage) throws -> String {
        guard let cg = image.cgImage else { throw ReadError.empty }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US", "de-DE", "fr-FR", "es-ES", "it-IT", "ro-RO"]
        let handler = VNImageRequestHandler(cgImage: cg, orientation: cgOrientation(image.imageOrientation))
        try handler.perform([request])
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return lines.joined(separator: "\n")
    }

    private static func cgOrientation(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch o {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    // MARK: Word .docx (a zip file with word/document.xml inside)

    static func docxText(_ data: Data) throws -> String {
        guard let xmlData = unzip(data, entry: "word/document.xml"),
              let xml = String(data: xmlData, encoding: .utf8) else { throw ReadError.empty }
        var s = xml.replacingOccurrences(of: "</w:p>", with: "\n")
        s = s.replacingOccurrences(of: "<w:tab/>", with: " ")
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        for (k, v) in ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'"] {
            s = s.replacingOccurrences(of: k, with: v)
        }
        return s
    }

    private static func unzip(_ data: Data, entry: String) -> Data? {
        let b = [UInt8](data)
        func u16(_ o: Int) -> Int { o + 1 < b.count ? Int(b[o]) | Int(b[o + 1]) << 8 : 0 }
        func u32(_ o: Int) -> Int { o + 3 < b.count ? u16(o) | u16(o + 2) << 16 : 0 }
        // End of central directory record
        var eocd = -1
        var i = b.count - 22
        while i >= 0 {
            if u32(i) == 0x06054b50 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { return nil }
        let count = u16(eocd + 10)
        var p = u32(eocd + 16)
        for _ in 0..<count {
            guard u32(p) == 0x02014b50 else { return nil }
            let method = u16(p + 10), compSize = u32(p + 20), size = u32(p + 24)
            let nameLen = u16(p + 28), extraLen = u16(p + 30), commentLen = u16(p + 32), local = u32(p + 42)
            guard p + 46 + nameLen <= b.count else { return nil }
            let name = String(decoding: b[(p + 46)..<(p + 46 + nameLen)], as: UTF8.self)
            if name == entry {
                let start = local + 30 + u16(local + 26) + u16(local + 28)
                guard start + compSize <= b.count else { return nil }
                let slice = Array(b[start..<(start + compSize)])
                if method == 0 { return Data(slice) }
                if method == 8 { return inflate(slice, expectedSize: size) }
                return nil
            }
            p += 46 + nameLen + extraLen + commentLen
        }
        return nil
    }

    /// Raw DEFLATE (zip method 8). Apple's COMPRESSION_ZLIB is raw deflate without a header.
    private static func inflate(_ src: [UInt8], expectedSize: Int) -> Data? {
        let capacity = max(expectedSize, src.count * 8, 1024)
        var dst = [UInt8](repeating: 0, count: capacity)
        let n = src.withUnsafeBufferPointer { s -> Int in
            guard let base = s.baseAddress else { return 0 }
            return compression_decode_buffer(&dst, capacity, base, src.count, nil, COMPRESSION_ZLIB)
        }
        return n > 0 ? Data(dst[0..<n]) : nil
    }

    // MARK: Picking out course lines

    /// Learning Agreements list courses in "Table A" rows that start with a reference code,
    /// e.g. "MOD-01 Datenbanken … Wintersemester 5". Returns names with ECTS, or [] if the text isn't one.
    static func learningAgreementCourses(_ text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        func firstIndex(_ pattern: String, from start: Int) -> Int? {
            guard start < lines.count else { return nil }
            return lines[start...].firstIndex { $0.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil }
        }
        let start = firstIndex("\\b(tabelle|table|tabla|tableau)\\s*a\\b", from: 0) ?? 0
        let end = firstIndex("\\b(tabelle|table|tabla|tableau)\\s*b\\b", from: start + 1) ?? lines.count
        guard start < end else { return [] }

        let codePattern = "^([A-Z]{2,6}[-\\s]?\\d{1,4}[A-Z]?)\\b\\s*(.*)$"
        let cutPattern = "\\s{2,}|\\s+(winter|sommer|summer|spring|autumn|fall|ws|ss|semester|ausstehend|pending)\\w*|\\s+\\d{1,2}([.,]\\d)?\\s*(ects|cr|cp)?\\s*$"
        guard let codeRe = try? NSRegularExpression(pattern: codePattern),
              let cutRe = try? NSRegularExpression(pattern: cutPattern, options: .caseInsensitive) else { return [] }

        // Row starts
        var rows: [(index: Int, rest: String)] = []
        for i in start..<end {
            let l = lines[i]
            let ns = l as NSString
            if let m = codeRe.firstMatch(in: l, range: NSRange(location: 0, length: ns.length)) {
                rows.append((i, ns.substring(with: m.range(at: 2))))
            }
        }
        var out: [String] = []
        for (k, row) in rows.enumerated() {
            var name = row.rest.trimmingCharacters(in: .whitespaces)
            if name.isEmpty, row.index + 1 < end { name = lines[row.index + 1] }
            let ns = name as NSString
            if let cut = cutRe.firstMatch(in: name, range: NSRange(location: 0, length: ns.length)) {
                name = ns.substring(to: cut.range.location)
            }
            name = name.trimmingCharacters(in: CharacterSet(charactersIn: " -–·:"))
            guard name.filter({ $0.isLetter }).count >= 4 else { continue }
            // ECTS: the last small whole number in this row's lines
            let rowEnd = k + 1 < rows.count ? rows[k + 1].index : end
            let block = lines[row.index..<rowEnd].joined(separator: " ").dropFirst(8)
            let numbers = block.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }.filter { (1...30).contains($0) }
            if let ects = numbers.last { name += " – \(ects) ECTS" }
            out.append(name)
        }
        return out.count >= 2 ? out : []
    }

    static func guessCourses(_ text: String) -> [String] {
        let la = learningAgreementCourses(text)
        if !la.isEmpty { return la }
        let bad = "^(page|seite|pagina|student|name|nume|signature|unterschrift|date|datum|data|university|universit|faculty|fakult|semester|total|summe|learning agreement|table|tabelle|code|ects|credits|course title|component|receiving|sending|responsible|coordinator|e-?mail|tel)\\b"
        var out: [String] = []
        for raw in text.components(separatedBy: .newlines) {
            var l = raw.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            if l.count < 4 || l.count > 140 { continue }
            if l.range(of: bad, options: [.regularExpression, .caseInsensitive]) != nil { continue }
            if l.contains("@") || l.lowercased().contains("http") || l.lowercased().contains("www.") { continue }
            if l.hasSuffix(".") || l.split(separator: " ").count > 9 || l.filter({ $0 == "," }).count >= 2 { continue }
            let letters = l.filter { $0.isLetter }.count
            if letters < 4 || Double(letters) / Double(l.count) < 0.5 { continue }
            l = l.replacingOccurrences(of: "^[\\d.\\-–•*)\\s]+", with: "", options: .regularExpression)
            if !out.contains(l) { out.append(l) }
        }
        let withCredits = out.filter {
            $0.range(of: "ects|\\bcr\\b|credits?|leistungspunkte|\\bcp\\b", options: [.regularExpression, .caseInsensitive]) != nil
        }
        return Array((withCredits.count >= 2 ? withCredits : out).prefix(40))
    }
}
