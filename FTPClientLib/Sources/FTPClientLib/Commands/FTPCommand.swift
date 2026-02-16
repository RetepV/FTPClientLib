//
//  FTPCommand.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 18-12-2025.
//

import Foundation

enum FTPCommandGroup {
    // ABOR, ALLO, DELE, CWD, CDUP, SMNT, HELP, MODE, NOOP, PASV, QUIT, SITE, PORT, SYST, STAT, RMD, MKD, PWD, STRU, TYPE
    case simple
    // APPE, LIST, NLST, REIN, RETR, STOR, STOU
    case simpleExtended
    // RNFR -> RNTO
    case rename
    // REST -> APPE, STOR, RETR
    case restart
    // USER -> PASS -> ACCT
    case login
}

enum FTPCommandType {
    case controlConnectionOnly
    case receiveWithDataConnection
    case sendWithDataConnection
}

enum FTPSourceOrDestinationType {
    case none
    case memory
    case file
}

protocol FTPCommand : CustomStringConvertible, Sendable {
    
    var commandString: String? { get }
    
    var commandGroup: FTPCommandGroup { get }
    var commandType: FTPCommandType { get }
    
    var sourceOrDestinationType: FTPSourceOrDestinationType { get }
    
    var fileURL: URL? { get }
    var data: Data? { get }
}

extension FTPCommand {
    
    public var description: String {
        if let commandString = self.commandString?.trimmingCharacters(in: .newlines) {
            return "\"\(commandString)\" - commandGroup: \(self.commandGroup), commandType: \(self.commandType)"
        }
        
        return "Unknown Command"
    }
}
