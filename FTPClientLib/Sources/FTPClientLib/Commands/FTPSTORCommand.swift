//
//  FTPSTORCommand.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 05-01-2026.
//

import Foundation

struct FTPSTORCommand: FTPCommand {

    // MARK: - Private
    
    private let _command = "STOR"
    
    private let _fileURL: URL

    // MARK: - Lifecycle
    
    init(fileURL: URL) {
        self._fileURL = fileURL
    }

    // MARK: - FTPCommand protocol
    
    // 125, 150, (110), 226, 250, 425, 426, 451, 551, 552, 532, 450, 452, 553, 500, 501, 421, 530
    let expectedResponseCodes: [Int] = [
        FTPResponseCodes.dataConnectionAlreadyOpen,
        FTPResponseCodes.fileStatusOK,
        FTPResponseCodes.restartMarkerReply,
        FTPResponseCodes.fileActionCompleted,
        FTPResponseCodes.requestedFileActionOk,
        FTPResponseCodes.connectionRefused,
        FTPResponseCodes.connectionClosedAbnormally,
        
        FTPResponseCodes.actionAbortedLocalErrorInProcessing,
        FTPResponseCodes.actionAbortedPageTypeNotRecognized,
        FTPResponseCodes.actionAbortedInsufficientStorage,
        FTPResponseCodes.needAccountForStoringFiles,
        FTPResponseCodes.fileActionNotTakenFileUnavailable,

        FTPResponseCodes.actionNotTakenFileNameNotAllowed,
        FTPResponseCodes.syntaxErrorUnrecognizedCommand,
        FTPResponseCodes.syntaxErrorInParameters,
        FTPResponseCodes.serviceNotAvailableClosingControlConnection,
        FTPResponseCodes.notLoggedIn
    ]

    var commandString: String? {
        _command.appending(" \(_fileURL.lastPathComponent)\r\n")
    }

    var commandType: FTPCommandType {
        .sendWithDataConnection
    }
    
    var commandGroup: FTPCommandGroup {
        .simpleExtended
    }
    
    var sourceOrDestinationType: FTPSourceOrDestinationType {
        .file
    }
    
    var fileURL: URL? {
        _fileURL
    }
    
    var data: Data? {
        nil
    }
}
