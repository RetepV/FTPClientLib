//
//  FTPPWDCommand.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 05-01-2026.
//

import Foundation

struct FTPPWDCommand: FTPCommand {

    // MARK: - Private
    
    private let _command = "PWD"

    // MARK: - Lifecycle
    
    init() {
    }

    // MARK: - FTPCommand protocol
    
    // 257, 500, 501, 502, 421, 550, 530
    let expectedResponseCodes: [Int] = [
        FTPResponseCodes.pathNameCreated,
        FTPResponseCodes.syntaxErrorUnrecognizedCommand,
        FTPResponseCodes.syntaxErrorInParameters,
        FTPResponseCodes.commandNotImplemented,
        FTPResponseCodes.serviceNotAvailableClosingControlConnection,
        FTPResponseCodes.actionNotTakenFileUnavailable,
        FTPResponseCodes.notLoggedIn
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
    
    var fileURL: URL? {
        nil
    }
    
    var data: Data? {
        nil
    }
}
