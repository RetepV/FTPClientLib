//
//  FTPTYPECommand.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 05-01-2026.
//

import Foundation

public enum FTPTypeCode: String, Sendable {
    case ascii = "A"
    case image = "I"            // Binary, but it's called 'Image' in RFC-959
    case ebcdic = "E"           // Not supported, but here for completeness.
    case local = "L"            // Not supported, but here for completeness.
}

struct FTPTYPECommand: FTPCommand {

    // MARK: - Private
    
    private let _command = "TYPE"

    private let _type: FTPTypeCode

    // MARK: - Lifecycle
    
    init(_ type: FTPTypeCode = .image) {
        _type = type
    }

    // MARK: - FTPCommand protocol
    
    // 200, 500, 501, 504, 421, 530
    let expectedResponseCodes: [Int] = [
        FTPResponseCodes.commandOk,
        FTPResponseCodes.syntaxErrorUnrecognizedCommand,
        FTPResponseCodes.syntaxErrorInParameters,
        FTPResponseCodes.commandNotImplementedForParameter,
        FTPResponseCodes.serviceNotAvailableClosingControlConnection,
        FTPResponseCodes.notLoggedIn
    ]

    var commandString: String? {
        _command.appending(" \(_type.rawValue)\r\n")
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
