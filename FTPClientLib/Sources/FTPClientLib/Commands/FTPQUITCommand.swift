//
//  FTPQUITCommand.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 05-01-2026.
//

import Foundation

struct FTPQUITCommand: FTPCommand {

    // MARK: - Private
    
    private let _command = "QUIT"

    // MARK: - Lifecycle
    
    init() {
    }

    // MARK: - FTPCommand protocol
    
    // 221, 500
    let expectedResponseCodes: [Int] = [
        FTPResponseCodes.serviceClosingConnection,
        FTPResponseCodes.syntaxErrorUnrecognizedCommand
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
