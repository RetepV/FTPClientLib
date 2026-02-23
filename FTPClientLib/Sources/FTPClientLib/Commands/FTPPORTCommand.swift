//
//  FTPPORTCommand.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 18-12-2025.


import Foundation

struct FTPPORTCommand: FTPCommand {

    // MARK: - Private
    
    private let _command = "PORT"
    private let _ipAddress: FTPIPAddress
    private let _ipPort: FTPIPPort

    // MARK: - Lifecycle
    
    init(ipAddress: FTPIPAddress, ipPort: FTPIPPort) {
        self._ipAddress = ipAddress
        self._ipPort = ipPort
    }

    // MARK: - FPTCommand protocol
    
    // 200, 500, 501, 421, 530
    let expectedResponseCodes: [Int] = [
        FTPResponseCodes.commandOk,
        FTPResponseCodes.syntaxErrorUnrecognizedCommand,
        FTPResponseCodes.syntaxErrorInParameters,
        FTPResponseCodes.serviceNotAvailableClosingControlConnection,
        FTPResponseCodes.notLoggedIn
    ]

    var commandString: String? {
        guard let addressString = _ipAddress.addressAsCommaSeparatedString,
              let portString = _ipPort.portAsCommaSeparatedTupleString else {
            return nil
        }
        return _command.appending(" \(addressString),\(portString)\r\n")
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
