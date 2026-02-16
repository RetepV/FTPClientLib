//
//  FTPLISTCommand.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 02-01-2026.
//

import Foundation

struct FTPLISTCommand: FTPCommand {
    
    // MARK: - Private
    
    private let _command = "LIST"
    private let path: String?
    
    // MARK: - Lifecycle
    
    init(path: String?) {
        self.path = path
    }
    
    // MARK: - FTPCommand protocol
    
    // 125, 150, 226, 250, 425, 426, 451, 450, 500, 501, 502, 421, 530
    let expectedResponseCodes: [Int] = [
        FTPResponseCodes.dataConnectionAlreadyOpen,
        FTPResponseCodes.fileStatusOK,
        FTPResponseCodes.fileActionCompleted,
        FTPResponseCodes.requestedFileActionOk,
        FTPResponseCodes.connectionRefused,
        FTPResponseCodes.connectionClosedAbnormally,
        FTPResponseCodes.actionAbortedLocalErrorInProcessing,
        FTPResponseCodes.fileActionNotTakenFileUnavailable,
        FTPResponseCodes.syntaxErrorUnrecognizedCommand,
        FTPResponseCodes.syntaxErrorInParameters,
        FTPResponseCodes.commandNotImplemented,
        FTPResponseCodes.serviceNotAvailableClosingControlConnection,
        FTPResponseCodes.notLoggedIn
    ]
    
    var commandString: String? {
        _command.appending(" -al \(path ?? "")\r\n")
    }
    
    var commandType: FTPCommandType {
        .receiveWithDataConnection
    }
    
    var commandGroup: FTPCommandGroup {
        .simpleExtended
    }
    
    var sourceOrDestinationType: FTPSourceOrDestinationType {
        .memory
    }
    
    var fileURL: URL? {
        nil
    }
    
    var data: Data? {
        nil
    }
}
