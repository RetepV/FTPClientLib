//
//  FTPACCTCommand.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 18-12-2025.
//

import Foundation

struct FTPACCTCommand : FTPCommand {
    
    // MARK: - Definitions
    
    private let _command = "ACCT"

    // RFC 959 says to expect 230, 202, 530, 500, 501, 503, 421
    public let expectedResponseCodes: [Int] = [
        FTPResponseCodes.userLoggedIn,
        FTPResponseCodes.commandNotImplementedSuperfluousAtThisSite,
        FTPResponseCodes.notLoggedIn,
        FTPResponseCodes.syntaxErrorUnrecognizedCommand,
        FTPResponseCodes.syntaxErrorInParameters,
        FTPResponseCodes.badSequenceOfCommands,
        FTPResponseCodes.serviceNotAvailableClosingControlConnection
    ]
    
    // MARK: - Private
    
    private let _account: String

    // MARK: - Lifecycle
    
    init(account: String) {
        self._account = account
    }
    
    // MARK: - Protocol
    
    var commandString: String? {
        _command.appending(" \(_account)\r\n")
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
    
    var fileURL: URL? {
        nil
    }
    
    var data: Data? {
        nil
    }
}
