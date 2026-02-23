//
//  FTPPASSCommand.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 18-12-2025.
//

import Foundation

struct FTPPASSCommand: FTPCommand {

    // MARK: - Definitions
    
    private let _command = "PASS"
    // 230, 202, 530, 500, 501, 503, 421, 332
    let expectedResponseCodes: [Int] = [
        FTPResponseCodes.userLoggedIn,
        FTPResponseCodes.commandNotImplementedSuperfluousAtThisSite,
        FTPResponseCodes.notLoggedIn,
        FTPResponseCodes.syntaxErrorUnrecognizedCommand,
        FTPResponseCodes.syntaxErrorInParameters,
        FTPResponseCodes.badSequenceOfCommands,
        FTPResponseCodes.serviceNotAvailableClosingControlConnection,
        FTPResponseCodes.needAccountForLogin
    ]

    // MARK: - Private
    
    private let password: String

    // MARK: - Lifecycle
    
    init(password: String) {
        self.password = password
    }

    // MARK: - Protocol
    
    var commandString: String? {
        _command.appending(" \(password)\r\n")
    }

    var commandType: FTPCommandType {
        .controlConnectionOnly
    }
    
    var commandGroup: FTPCommandGroup {
        .login
    }
    
    var sourceOrDestinationType: FTPSourceOrDestinationType {
        .none
    }
}
