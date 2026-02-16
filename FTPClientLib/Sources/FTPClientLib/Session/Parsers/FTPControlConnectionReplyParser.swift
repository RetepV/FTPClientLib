//
//  FTPControlConnectionReplyParser.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 19-12-2025.
//

import Foundation

struct FTPControlConnectionReplyParser {
    
    // This function parses the passed data as a list of lines. Each line must end in a "\r\n". If
    // the last line in the data is incomplete (i.e. doesn't end in a "\r\n", the incompletely parsed part of
    // the data is returned. If the caller receives new data, it can then prepend the unparsed data so that
    // it will be parsed in the next call to parse()
    static func parse(_ data: Data, commandGroup: FTPCommandGroup) throws -> (code: Int?, complete: Bool, parsed: String?, unparsedData: Data?) {

        let lineDelimiter: String = "\r\n"

        var message = String(data: data, encoding: .utf8)
        
        guard message != nil  else {
            throw FTPError(.parseResponseFailed, userinfo: [NSLocalizedDescriptionKey : "Failed to convert the data to UTF8 string"])
        }
        
        // We aggregate all the lines in here.
        var responseMessage: String? = nil
        var responseCode: Int? = nil
        var complete: Bool = false
        
        var eolIndex: String.Index? = message!.firstIndex(of: lineDelimiter)
        
        while eolIndex != nil {
            
            let line = String(message![..<eolIndex!])
            
            // If there are fewer than 3 characters left, then we can't parse anymore. Return what we have. But we're not complete.
            if line.count < 3 {
                return (responseCode, false, responseMessage, line.data(using: .utf8))
            }
            
            let codeString = String(line.prefix(3))
            if let code = Int(codeString) {
                responseCode = code
            }
            
            let continuationMarker = String(line[line.index(line.startIndex, offsetBy: 3)])
            if continuationMarker != "-" {
                if let responseCode, (commandGroup == .simpleExtended) && (100..<200).contains(responseCode) {
                    // In case of .simpleExtended command group, we accepts series 100 messages as not an end
                    // of transmission, so we are not complete yet.
                }
                else {
                    complete = true
                }
            }
            
            let actualMessage = String(line.dropFirst(4))
            responseMessage = (responseMessage ?? "") + actualMessage
            
            if !complete {
                responseMessage = (responseMessage ?? "") + "\r\n"
            }

            message = String(message!.dropFirst(line.count + lineDelimiter.count))
            eolIndex = message!.firstIndex(of: lineDelimiter)
        }
        
        return (responseCode, complete, responseMessage, message?.data(using: .utf8))
    }
    
    static func parseOneLine(_ data: Data, commandGroup: FTPCommandGroup) throws -> (code: Int?, complete: Bool, parsed: String?, unparsedData: Data?) {

        let lineDelimiter: String = "\r\n"

        var message = String(data: data, encoding: .utf8)
        
        guard message != nil  else {
            throw FTPError(.parseResponseFailed, userinfo: [NSLocalizedDescriptionKey : "Failed to convert the data to UTF8 string"])
        }
        
        // We aggregate all the lines in here.
        var responseMessage: String? = nil
        var responseCode: Int? = nil
        var complete: Bool = false
        
        var eolIndex: String.Index? = message!.firstIndex(of: lineDelimiter)
        
        while eolIndex != nil {
            
            let line = String(message![..<eolIndex!])
            
            // If there are fewer than 3 characters left, then we can't parse anymore. Return what we have. But we're not complete.
            if line.count < 3 {
                return (responseCode, false, responseMessage, line.data(using: .utf8))
            }
            
            let codeString = String(line.prefix(3))
            if let code = Int(codeString) {
                responseCode = code
            }
            
            let continuationMarker = String(line[line.index(line.startIndex, offsetBy: 3)])
            if continuationMarker != "-" {
                complete = true
            }
            
            let actualMessage = String(line.dropFirst(4))
            responseMessage = (responseMessage ?? "") + actualMessage
            
            if !complete {
                responseMessage = (responseMessage ?? "") + "\r\n"
            }

            message = String(message!.dropFirst(line.count + lineDelimiter.count))
            eolIndex = message!.firstIndex(of: lineDelimiter)
        }
        
        return (responseCode, complete, responseMessage, message?.data(using: .utf8))
    }
}
