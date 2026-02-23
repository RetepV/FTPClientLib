//
//  FTPUSERCommand.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 18-12-2025.
//

import Foundation

struct FTPUSERCommand : FTPCommand {
    
    // MARK: - Definitions
    
    private let _command = "USER"
    
    // RFC 959 says to expect 230, 530, 500, 501, 421, 331, 332
    public let expectedResponseCodes: [Int] = [
        FTPResponseCodes.userLoggedIn,
        FTPResponseCodes.notLoggedIn,
        FTPResponseCodes.syntaxErrorUnrecognizedCommand,
        FTPResponseCodes.syntaxErrorInParameters,
        FTPResponseCodes.serviceNotAvailableClosingControlConnection,
        FTPResponseCodes.userNameOkNeedsPassword,
        FTPResponseCodes.needAccountForLogin
    ]
    
    // MARK: - Private
    
    private let username: String
    
    // MARK: - Lifecycle
    
    init(username: String) {
        self.username = username
    }
    
    // MARK: - Protocol
    
    var commandString: String? {
        _command.appending(" \(username)\r\n")
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
