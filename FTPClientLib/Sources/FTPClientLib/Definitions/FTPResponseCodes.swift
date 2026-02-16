//
//  FTPResponseCodes.swift
//  FTPClient
//
//  Created by Peter de Vroomen on 06-02-2025.
//

import Foundation

// All known FTP response codes from RFC-959.

struct FTPResponseCodes {
    
    static let restartMarkerReply = 110
    static let serviceReadyInNNNMinutes = 120
    static let dataConnectionAlreadyOpen = 125
    static let fileStatusOK = 150
    
    static let commandOk = 200
    static let commandNotImplementedSuperfluousAtThisSite = 202
    static let systemStatus = 211
    static let directoryStatus = 212
    static let fileStatus = 213
    static let helpMessage = 214
    static let nameSystemType = 215
    static let serviceReadyForNewUser = 220
    static let serviceClosingConnection = 221
    static let dataConnectionOpened = 225
    static let fileActionCompleted = 226
    static let enteringPassiveMode = 227
    static let userLoggedIn = 230
    static let requestedFileActionOk = 250
    static let pathNameCreated = 257

    static let userNameOkNeedsPassword = 331
    static let needAccountForLogin = 332
    static let requestedFileActionPending = 350
    
    static let serviceNotAvailableClosingControlConnection = 421
    static let connectionRefused = 425
    static let connectionClosedAbnormally = 426
    static let fileActionNotTakenFileUnavailable = 450
    static let actionAbortedLocalErrorInProcessing = 451
    static let actionNotTakeInsufficientStorage = 452

    static let syntaxErrorUnrecognizedCommand = 500
    static let syntaxErrorInParameters = 501
    static let commandNotImplemented = 502
    static let badSequenceOfCommands = 503
    static let commandNotImplementedForParameter = 504
    
    static let notLoggedIn = 530
    static let needAccountForStoringFiles = 532
    static let actionNotTakenFileUnavailable = 550
    static let actionAbortedPageTypeNotRecognized = 551
    static let actionAbortedInsufficientStorage = 552
    static let actionNotTakenFileNameNotAllowed = 553
}
