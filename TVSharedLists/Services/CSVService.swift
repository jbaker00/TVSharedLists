import Foundation
import UniformTypeIdentifiers
import SwiftUI

// MARK: - FileDocument for .fileExporter

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }
    static var writableContentTypes: [UTType] { [.commaSeparatedText] }

    var content: String

    init(content: String) {
        self.content = content
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        content = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: content.data(using: .utf8) ?? Data())
    }
}

// MARK: - Import errors

enum CSVImportError: LocalizedError {
    case emptyFile
    case invalidHeader(expected: String, got: String)
    case invalidRow(line: Int, reason: String)
    case noValidRows
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "The file is empty."
        case .invalidHeader(let expected, let got):
            return """
            Invalid CSV header — the columns don't match the expected format.

            Expected:
            \(expected)

            Found:
            \(got)

            Please export from this app first to get the correct format, or fix your column headers.
            """
        case .invalidRow(let line, let reason):
            return "Row \(line) is invalid: \(reason)"
        case .noValidRows:
            return "No valid show rows were found in the file."
        case .downloadFailed(let msg):
            return "Could not download the file: \(msg)"
        }
    }
}

// MARK: - Service

struct CSVService {

    /// Current header (10 columns). The legacy 9-column header (without Status) is also accepted on import.
    static let headerRow = "Title,Network,Genres,Rating,Thumbs,Notes,Added Date,TVMaze ID,Summary,Status"
    private static let legacyHeaderRow = "Title,Network,Genres,Rating,Thumbs,Notes,Added Date,TVMaze ID,Summary"

    // MARK: - Export

    static func exportCSV(shows: [TVShow]) -> String {
        var rows = [headerRow]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        for show in shows {
            let thumbsStr: String
            switch show.thumbs {
            case "up":   thumbsStr = "Loved It"
            case "down": thumbsStr = "Not For Me"
            default:     thumbsStr = "None"
            }

            let row = [
                show.title,
                show.network,
                show.genres.joined(separator: "; "),
                "\(show.rating)",
                thumbsStr,
                show.notes,
                formatter.string(from: show.addedAt),
                show.tvMazeId >= 0 ? "\(show.tvMazeId)" : "-1",
                show.summary,
                show.wantToWatch ? "Want to Watch" : "Watched"
            ]
            .map { csvEscape($0) }
            .joined(separator: ",")

            rows.append(row)
        }

        return rows.joined(separator: "\n")
    }

    // MARK: - Import

    static func importCSV(_ csvString: String) throws -> [TVShow] {
        let normalized = csvString
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let lines = normalized
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard !lines.isEmpty else { throw CSVImportError.emptyFile }

        let header = lines[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let isLegacy = header.lowercased() == legacyHeaderRow.lowercased()
        let isCurrent = header.lowercased() == headerRow.lowercased()

        if !isLegacy && !isCurrent {
            throw CSVImportError.invalidHeader(expected: headerRow, got: header)
        }

        let expectedColumns = isLegacy ? 9 : 10
        guard lines.count > 1 else { throw CSVImportError.noValidRows }

        var shows: [TVShow] = []
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        for (index, line) in lines.dropFirst().enumerated() {
            let lineNumber = index + 2
            let fields = parseCSVRow(line)

            guard fields.count >= expectedColumns else {
                throw CSVImportError.invalidRow(
                    line: lineNumber,
                    reason: "Expected \(expectedColumns) columns but found \(fields.count). Check for missing commas or extra line breaks in notes/summary fields."
                )
            }

            let title = fields[0].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else {
                throw CSVImportError.invalidRow(line: lineNumber, reason: "Title column cannot be empty.")
            }

            let ratingStr = fields[3].trimmingCharacters(in: .whitespacesAndNewlines)
            guard let rating = Int(ratingStr), rating >= 0, rating <= 5 else {
                throw CSVImportError.invalidRow(
                    line: lineNumber,
                    reason: "Rating must be a whole number from 0 to 5, but found \"\(ratingStr)\"."
                )
            }

            let thumbsRaw = fields[4].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let thumbs: String
            switch thumbsRaw {
            case "loved it", "up":     thumbs = "up"
            case "not for me", "down": thumbs = "down"
            default:                   thumbs = "none"
            }

            let dateStr = fields[6].trimmingCharacters(in: .whitespacesAndNewlines)
            let date = dateFormatter.date(from: dateStr) ?? Date()

            let tvMazeId = Int(fields[7].trimmingCharacters(in: .whitespacesAndNewlines)) ?? -1

            let genresRaw = fields[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let genres: [String] = genresRaw.isEmpty
                ? []
                : genresRaw
                    .components(separatedBy: "; ")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

            let wantToWatch: Bool
            if isLegacy {
                wantToWatch = false
            } else {
                let statusRaw = fields[9].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                wantToWatch = statusRaw == "want to watch"
            }

            shows.append(TVShow(
                title:       title,
                network:     fields[1].trimmingCharacters(in: .whitespacesAndNewlines),
                posterURL:   "",
                summary:     fields[8].trimmingCharacters(in: .whitespacesAndNewlines),
                genres:      genres,
                rating:      rating,
                thumbs:      thumbs,
                notes:       fields[5].trimmingCharacters(in: .whitespacesAndNewlines),
                addedAt:     date,
                tvMazeId:    tvMazeId,
                wantToWatch: wantToWatch
            ))
        }

        guard !shows.isEmpty else { throw CSVImportError.noValidRows }
        return shows
    }

    // MARK: - RFC 4180 CSV row parser

    static func parseCSVRow(_ row: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = row.startIndex

        while i < row.endIndex {
            let c = row[i]

            if inQuotes {
                if c == "\"" {
                    let next = row.index(after: i)
                    if next < row.endIndex && row[next] == "\"" {
                        current.append("\"")
                        i = row.index(after: next)
                        continue
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(c)
                }
            } else {
                if c == "\"" {
                    inQuotes = true
                } else if c == "," {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(c)
                }
            }

            i = row.index(after: i)
        }

        fields.append(current)
        return fields
    }

    // MARK: - Helpers

    private static func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
