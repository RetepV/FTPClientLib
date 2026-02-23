//
//  FTPNOOPCommand.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 22-02-2026.
//

import Foundation

struct FTPNOOPCommand: FTPCommand {

    // MARK: - Private
    
    private let _command = "NOOP"

    // MARK: - Lifecycle
    
    init() {
    }

    // MARK: - FTPCommand protocol
    
    // 200, 500, 421
    let expectedResponseCodes: [Int] = [
        FTPResponseCodes.commandOk,
        FTPResponseCodes.syntaxErrorUnrecognizedCommand,
        FTPResponseCodes.serviceNotAvailableClosingControlConnection,
    ]

    var commandString: String? {
        _command.appending("\r\n")
    }

    var commandType: FTPCommandType {
        .controlConnectionOnly
    }
    
    var commandGroup: FTPCommandGroup {
        .simple
    }
    
    var sourceOrDestinationType: FTPSourceOrDestinationType {
        .none
    }
}
