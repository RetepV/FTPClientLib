//
//  FTPPASVReplyParser.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 03-01-2026.
//

import Foundation
import Network

struct FTPPASVReplyParser {
    
    // It is not strictly specified how the server might return the IP address and port to connect to.
    //
    // Examples of how the information might be returned, and these are what we support:
    //
    // Entering Passive Mode (h1,h2,h3,h4,p1,p2)        /^[^\d]*\((\d+),(\d+),(\d+),(\d+),(\d+),(\d+)\)/
    // Entering Passive Mode (h1,h2,h3,h4,p1,p2         /^[^\d]*\((\d+),(\d+),(\d+),(\d+),(\d+),(\d+)/
    // Entering Passive Mode. h1,h2,h3,h4,p1,p2         /^[^\d]*(\d+),(\d+),(\d+),(\d+),(\d+),(\d+)/
    // =h1,h2,h3,h4,p1,p2                               /^=(\d+),(\d+),(\d+),(\d+),(\d+),(\d+)/
    //
    // Be aware that some FTP servers might even return IPv6 addresses or DNS names, all is game. Add more
    // matches if necessary.
    
    static func parse(message: String) throws -> (FTPIPAddress, FTPIPPort) {
        
        var ipAddress: FTPIPAddress? = nil
        var ipPort: FTPIPPort? = nil

        if let match = message.firstMatch(of: /^[^\d]*\((\d+),(\d+),(\d+),(\d+),(\d+),(\d+)\)/) {
            if let h1 = UInt8(match.1), let h2 = UInt8(match.2), let h3 = UInt8(match.3), let h4 = UInt8(match.4), let p1 = UInt8(match.5), let p2 = UInt8(match.6) {
                ipAddress = FTPIPAddress(h1, h2, h3, h4)
                ipPort = FTPIPPort(p1, p2)
            }
        }
        else if let match = message.firstMatch(of: /^[^\d]*\((\d+),(\d+),(\d+),(\d+),(\d+),(\d+)/) {
            if let h1 = UInt8(match.1), let h2 = UInt8(match.2), let h3 = UInt8(match.3), let h4 = UInt8(match.4), let p1 = UInt8(match.5), let p2 = UInt8(match.6) {
                ipAddress = FTPIPAddress(h1, h2, h3, h4)
                ipPort = FTPIPPort(p1, p2)
            }
        }
        else if let match = message.firstMatch(of: /^[^\d]*(\d+),(\d+),(\d+),(\d+),(\d+),(\d+)/) {
            if let h1 = UInt8(match.1), let h2 = UInt8(match.2), let h3 = UInt8(match.3), let h4 = UInt8(match.4), let p1 = UInt8(match.5), let p2 = UInt8(match.6) {
                ipAddress = FTPIPAddress(h1, h2, h3, h4)
                ipPort = FTPIPPort(p1, p2)
            }
        }
        else if let match = message.firstMatch(of: /^=(\d+),(\d+),(\d+),(\d+),(\d+),(\d+)/) {
            if let h1 = UInt8(match.1), let h2 = UInt8(match.2), let h3 = UInt8(match.3), let h4 = UInt8(match.4), let p1 = UInt8(match.5), let p2 = UInt8(match.6) {
                ipAddress = FTPIPAddress(h1, h2, h3, h4)
                ipPort = FTPIPPort(p1, p2)
            }
        }
        
        if ipAddress != nil && ipPort != nil {
            return (ipAddress!, ipPort!)
        }

        throw FTPError(.parseResponseFailed, userinfo: [NSLocalizedDescriptionKey : "FTPPASVReplyParser: Could not parse this FTP PASV reply: \(message)"])
    }
}
