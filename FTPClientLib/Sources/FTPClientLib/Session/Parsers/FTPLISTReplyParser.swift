//
//  FTPLISTReplyParser.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 05-01-2026.
//

import Foundation

// It is not strictly specified how the server might return the list of files. Therefore,
// we must first identify the list, and then choose a corresponding parser to parse the
// result.
//
// Initially, we only assume unix style listings, file types and access control.

let charactersToEscape: [Character] = ["-", "?", "^", ".", "\\"]

public enum FTPUnixFileType : Character, CaseIterable, Sendable {
    case regular = "-"
    case blockSpecial = "b"
    case characterSpecial = "c"
    case highPerformance = "C"
    case directory = "d"
    case door = "D"
    case symbolicLink = "l"
    case offline = "M"
    case networkSpecial = "n"
    case fifo = "p"
    case port = "P"
    case socket = "s"
    case unknown = "?"
    
    static var escapedSearchString: String {
        // "\\-bcCdDlMnpPs\\?"
        String(Self.allCases.map({
            return charactersToEscape.contains($0.rawValue) ? "\\" + String($0.rawValue) : String($0.rawValue)
        }).joined())
    }
}

public enum FTPUnixFileModeBits : Character, CaseIterable, Sendable {
    case read = "r"
    case write = "w"
    case setUidOrGidExecutable = "s"
    case setUidOrGidNotExecutable = "S"
    case stickyExecutable = "t"
    case stickyNotExecutable = "T"
    case executable = "x"
    case otherwise = "-"
    
    static var escapedSearchString: String {
        // "rwsStTx\\-"
        String(Self.allCases.map({
            return charactersToEscape.contains($0.rawValue) ? "\\" + String($0.rawValue) : String($0.rawValue)
        }).joined())
    }
}

struct FTPLISTReplyParser {
    
    static func parse(message: String) throws -> [FTPFileListItem] {
        
        var fileListItems: [FTPFileListItem] = []
        
        for line in message.split(separator: "\r\n") where !line.isEmpty {
            
            if let match = try parseUnixStyleLine(line: String(line)) {
                do {
                    try fileListItems.append(fileListItemFromUnixStyleMatch(match: match))
                }
                catch {
                    // Skip any that does not parse.
                    // throw FTPError(.parseResponseFailed, userinfo: [NSLocalizedDescriptionKey : "FTPPASVReplyParser: Could not parse this FTP LIST reply "])
                    continue
                }
            }
            
        }
        
        return fileListItems
    }
    
    static func parseUnixStyleLine(line: String) throws -> Regex<Regex<AnyRegexOutput>.RegexOutput>.Match? {
        
        let allUnixFileTypes = FTPUnixFileType.escapedSearchString
        let allUnixModeBits = FTPUnixFileModeBits.escapedSearchString
        
        let regex = try Regex("^([\(allUnixFileTypes)])([\(allUnixModeBits)]{3})([\(allUnixModeBits)]{3})([\(allUnixModeBits)]{3})\\s+(\\d+)\\s+([^\\s]+)\\s+([^\\s]+)\\s+(\\d+)\\s+([^\\s]+)\\s+([^\\s]+)\\s+([^\\s]+)\\s+(.+)")
        
        return line.firstMatch(of: regex)
    }
    
    static func fileListItemFromUnixStyleMatch(match: Regex<Regex<AnyRegexOutput>.RegexOutput>.Match) throws -> FTPFileListItem {
        
        guard let rawItemSubstring = match[0].substring,
              let unixFiletypeSubstring = match[1].substring, let unixFileType = FTPUnixFileType(rawValue: Character(String(unixFiletypeSubstring))),
              let unixUserModeFlagsSubstring = match[2].substring,
              let unixGroupModeFlagsSubstring = match[3].substring,
              let unixOtherModeFlagsSubstring = match[4].substring,
              let unixFileLinksSubstring = match[5].substring,
              let unixUserIDSubstring = match[6].substring,
              let unixGroudIDSubstring = match[7].substring,
              let sizeInBytesSubstring = match[8].substring,
              let modifiedMonthSubstring = match[9].substring,
              let modifiedDaySubstring = match[10].substring,
              let modifiedYearOrTimeSubstring = match[11].substring,
              let filenameSubstring = match[12].substring else {
            throw FTPError(.parseResponseFailed, userinfo: [NSLocalizedDescriptionKey : "FTPPASVReplyParser: Unix-style match contained unexpected items"])
        }
        
        let userModeBits = String(unixUserModeFlagsSubstring).compactMap(FTPUnixFileModeBits.init(rawValue:))
        let groupModeBits = String(unixGroupModeFlagsSubstring).compactMap(FTPUnixFileModeBits.init(rawValue:))
        let otherModeBits = String(unixOtherModeFlagsSubstring).compactMap(FTPUnixFileModeBits.init(rawValue:))
        
        guard let sizeInBytes = UInt64(sizeInBytesSubstring) else {
            throw FTPError(.parseResponseFailed, userinfo: [NSLocalizedDescriptionKey : "FTPPASVReplyParser: Invalid size in bytes"])
        }
        
        var modifiedYear: String = String(modifiedYearOrTimeSubstring)
        var modifiedTime: String = "00:00"
        
        if modifiedYearOrTimeSubstring.contains(":") {
            modifiedYear = String(Calendar.current.component(.year, from: Date()))
            modifiedTime = String(modifiedYearOrTimeSubstring)
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy LLL dd hh:mm"

        guard let dateModified = dateFormatter.date(from: "\(modifiedYear) \(modifiedMonthSubstring) \(modifiedDaySubstring) \(modifiedTime)") else {
            throw FTPError(.parseResponseFailed, userinfo: [NSLocalizedDescriptionKey : "FTPPASVReplyParser: Invalid modified filedate format"])
        }
    
        return FTPFileListItem(rawItem: String(rawItemSubstring),
                               filename: String(filenameSubstring),
                               unixFiletype: unixFileType,
                               unixUserModeBits: userModeBits,
                               unixGroupModeBits: groupModeBits,
                               unixOtherModeBits: otherModeBits,
                               sizeInBytes: sizeInBytes,
                               dateModified: dateModified,
                               user: String(unixUserIDSubstring),
                               group: String(unixGroudIDSubstring))
    }
}
