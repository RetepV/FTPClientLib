//
//  FTPRETRCommand.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 05-01-2026.
//

import Foundation

struct FTPRETRCommand: FTPCommand {

    // MARK: - Private
    
    private let _command = "RETR"
    
    private let _remotePath: String
    private let _localFileURL: URL

    // MARK: - Lifecycle
    
    init(remotePath: String, localFileURL: URL) {
        self._remotePath = remotePath
        self._localFileURL = localFileURL
    }

    // MARK: - FTPCommand protocol
    
    // 125, 150, (110), 226, 250, 425, 426, 451, 450, 550, 501, 421, 530
    let expectedResponseCodes: [Int] = [
        FTPResponseCodes.dataConnectionAlreadyOpen,
        FTPResponseCodes.fileStatusOK,
        FTPResponseCodes.restartMarkerReply,
        FTPResponseCodes.fileActionCompleted,
        FTPResponseCodes.requestedFileActionOk,
        FTPResponseCodes.connectionRefused,
        FTPResponseCodes.connectionClosedAbnormally,
        
        FTPResponseCodes.actionAbortedLocalErrorInProcessing,
        FTPResponseCodes.fileActionNotTakenFileUnavailable,
        FTPResponseCodes.actionNotTakenFileUnavailable,

        FTPResponseCodes.actionNotTakenFileNameNotAllowed,
        
        FTPResponseCodes.syntaxErrorInParameters,
        FTPResponseCodes.serviceNotAvailableClosingControlConnection,
        FTPResponseCodes.notLoggedIn
    ]

    var commandString: String? {
        _command.appending(" \(_remotePath)\r\n")
    }

    var commandType: FTPCommandType {
        .receiveWithDataConnection
    }
    
    var commandGroup: FTPCommandGroup {
        .simpleExtended
    }
    
    var sourceOrDestinationType: FTPSourceOrDestinationType {
        .file
    }
    
    var remotePath: String {
        _remotePath
    }
    
    var localFileURL: URL? {
        _localFileURL
    }
}
