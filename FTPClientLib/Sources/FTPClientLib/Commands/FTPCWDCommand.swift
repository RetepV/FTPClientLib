//
//  FTPCWDCommand.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 05-01-2026.
//

import Foundation

struct FTPCWDCommand: FTPCommand {
    
    // MARK: - Private
    
    private let _command = "CWD"
    private let directory: String
    
    // MARK: - Lifecycle
    
    init(directory: String) {
        self.directory = directory
    }
    
    // MARK: - FTPCommand protocol
    
    // 250, 500, 501, 502, 421, 550, 530
    // NOTE: Some servers seem to return 257 for success, so add that too.
    let expectedResponseCodes: [Int] = [
        FTPResponseCodes.requestedFileActionOk,
        FTPResponseCodes.syntaxErrorUnrecognizedCommand,
        FTPResponseCodes.syntaxErrorInParameters,
        FTPResponseCodes.commandNotImplemented,
        FTPResponseCodes.serviceNotAvailableClosingControlConnection,
        FTPResponseCodes.actionNotTakenFileUnavailable,
        FTPResponseCodes.notLoggedIn,
        
        FTPResponseCodes.pathNameCreated        // demo.wftpserver.com returns this in case of success.
    ]
    
    var commandString: String? {
        _command.appending(" \(directory)\r\n")
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
