//
//  FTPPASVCommand.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 18-12-2025.


import Foundation

struct FTPPASVCommand: FTPCommand {

    // MARK: - Private
    
    private let _command = "PASV"
    private let _chainedCommand: FTPCommand

    // MARK: - Lifecycle
    
    init(chainedCommand: FTPCommand) {
        self._chainedCommand = chainedCommand
    }

    // MARK: - FPTCommand protocol
    
    // 227, 500, 501, 502, 421, 530
    let expectedResponseCodes: [Int] = [
        FTPResponseCodes.enteringPassiveMode,
        FTPResponseCodes.syntaxErrorUnrecognizedCommand,
        FTPResponseCodes.syntaxErrorInParameters,
        FTPResponseCodes.commandNotImplemented,
        FTPResponseCodes.serviceNotAvailableClosingControlConnection,
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
