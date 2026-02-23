//
//  File.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 15-10-2025.
//

import Foundation
import Network
import os

public actor FTPClientSession : Sendable, Observable {
    
    // MARK: - Public
    
    public var sessionState: FTPSessionState {
        get {
            return _sessionState
        }
        set {
            // Only update if the value is really new, we only want to process transitions.
            if _sessionState != newValue {
                Self.logger.info("FTPClientSession: sessionState: \(newValue.rawValue)")
                _sessionState = newValue
                // delegate.sessionStateUpdated(session: self, state: _sessionState)
            }
        }
    }
    public var serverURL: URL {
        get {
            controlConnectionURL
        }
    }
    public var dataConnectionMode: FTPDataConnectionMode {
        get {
            return _dataConnectionMode
        }
    }
    
    // MARK: - Private
    
    private var _sessionState: FTPSessionState = FTPSessionState.uninitialised
    private var _dataConnectionMode: FTPDataConnectionMode = .passive
    
    private var _representationType: FTPRepresentationType = .ascii
    private var _representationSubtype: FTPRepresentationSubtype? = nil
    private var _localByteSize: UInt64? = nil
    private var _fileStructure: FTPFileStructure = .file
    private var _transferMode: FTPTransferMode = .stream
    
    // MARK: - Internal
    
    internal static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: FTPClientSession.self))
    
    internal var controlConnectionURL: URL
    internal var controlConnection: FTPControlConnection? = nil
    
    // Most or all FTP servers cannot handle more than one control connection, data connection and command
    // at any one time. We must therefore make the sending of a command and receiving of a reply atomic
    // operations. *Even if started from different threads*
    internal let sendExecutionLock: AsyncSemaphore = .init(value: 1)
    // A few functions (like login) are actually sequences of multiple FTP commands. We do not want to start
    // a new command before the previous one has finished. *Even if started from different threads*.
    internal let commandExecutionLock: AsyncSemaphore = .init(value: 1)
    
    // MARK: - Lifecycle
    
    init(url: URL) {
        
        Self.logger.info("FTPClientSession: Initialize session with url: \(url)")
        
        controlConnectionURL = url
        
        _sessionState = .initialised
    }
    
    public func close() async throws {
        
        guard (sessionState == .opened) || (sessionState == .idle), controlConnection != nil else {
            Self.logger.info("FTPClientSession: Trying to close a session that is not idle")
            throw FTPError(.notOpened, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Session not idle"])
        }
        
        sessionState = .closing
        
        try await controlConnection?.disconnect()
        controlConnection = nil
        
        sessionState = .closed
    }
    
    public func setDataConnectionMode(_ mode: FTPDataConnectionMode) {
        _dataConnectionMode = mode
    }
    
    // MARK: - Internal
    
    internal func performCommand(_ command: some FTPCommand) async throws -> FTPCommandResult {
        
        Self.logger.info("FTPClientSession: Sending command: \(command)")
        
        await sendExecutionLock.wait()
        defer {sendExecutionLock.signal()}
        
        var result: FTPCommandResult? = nil
        
        switch command.commandType {
        case .controlConnectionOnly:
            result = try await doControlCommandOnly(command)
        case .receiveWithDataConnection:
            switch _dataConnectionMode {
            case .active:
                result = try await doReceiveWithActiveDataConnection(command)
            case .passive:
                result = try await doReceiveWithPassiveDataConnection(command)
            case .extendedActive:
                break
            case .extendedPassive:
                break
            }
        case .sendWithDataConnection:
            switch _dataConnectionMode {
            case .active:
                result = try await doSendWithActiveDataConnection(command)
            case .passive:
                result = try await doSendWithPassiveDataConnection(command)
            case .extendedActive:
                break
            case .extendedPassive:
                break
            }
        }
        
        if let result {
            return result
        }
        
        return FTPCommandResult(code: -1, message: "Not implemented")
    }
    
    // MARK: - Private
    
    private func doControlCommandOnly(_ command: some FTPCommand) async throws -> FTPCommandResult {
        
        guard (sessionState == .opened) || (sessionState == .idle), let controlConnection else {
            throw FTPError(.unknown, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: No control connection or session not idle"])
        }
        
        guard let commandString = command.commandString, commandString.isEmpty == false else {
            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Empty or no commandString"])
        }
        
        try await controlConnection.sendCommand(command)
        
        let reply = try await controlConnection.receiveReply(commandGroup: command.commandGroup)
        
        return FTPCommandResult(code: await reply.code,
                                message: await reply.message,
                                data: nil)
    }
    
    private func doReceiveWithActiveDataConnection(_ command: some FTPCommand) async throws -> FTPCommandResult {
        
        guard sessionState == .idle, let controlConnection else {
            throw FTPError(.unknown, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: No control connection or session not idle"])
        }
        
        guard let commandString = command.commandString, commandString.isEmpty == false else {
            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Empty or no commandString"])
        }
        
        guard command.sourceOrDestinationType != .none else {
            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Source or destination should not be .none here"])
        }
                
        // Set up the active data connection and start listening for connections.
        let dataConnection = try await makeActiveDataConnection()

        // Send actual command.
        try await controlConnection.sendCommand(command)
        
        // Wait for the server to connect to the data connection.
        try await dataConnection.waitForConnection(timeout: FTPClientLibDefaults.timeoutInSecondsForListen)
                
        // Read all the data.
        return try await doActualReceive(command: command, dataConnection: dataConnection)
    }
    
    private func doReceiveWithPassiveDataConnection(_ command: some FTPCommand) async throws -> FTPCommandResult {
        
        guard sessionState == .idle, let controlConnection else {
            throw FTPError(.unknown, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: No control connection or session not idle"])
        }
        
        guard let commandString = command.commandString, commandString.isEmpty == false else {
            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Empty or no commandString"])
        }
        
        // Make the passive data connection.
        let dataConnection = try await makePassiveDataConnection()
        
        // Send the actual command.
        try await controlConnection.sendCommand(command)
        
        // Read all the data.
        return try await doActualReceive(command: command, dataConnection: dataConnection)
    }
    
    private func doSendWithActiveDataConnection(_ command: some FTPCommand) async throws -> FTPCommandResult {
        
        guard sessionState == .idle, let controlConnection else {
            throw FTPError(.unknown, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: No control connection or session not idle"])
        }
        
        guard let commandString = command.commandString, commandString.isEmpty == false else {
            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Empty or no commandString"])
        }
        
        // Set up the active data connection and start listening for connections.
        let dataConnection = try await makeActiveDataConnection()
        
        // Send actual command.
        try await controlConnection.sendCommand(command)
        
        // Wait for the server to connect to the data connection.
        try await dataConnection.waitForConnection(timeout: FTPClientLibDefaults.timeoutInSecondsForListen)
        
        // Send the data.
        return try await doActualSend(command: command, dataConnection: dataConnection)
    }

    private func doSendWithPassiveDataConnection(_ command: some FTPCommand) async throws -> FTPCommandResult {
        
        guard sessionState == .idle, let controlConnection else {
            throw FTPError(.unknown, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: No control connection or session not idle"])
        }
        
        guard let commandString = command.commandString, commandString.isEmpty == false else {
            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Empty or no commandString"])
        }
        
        if command.sourceOrDestinationType == .file && (command.localFileURL == nil || !command.localFileURL!.isFileURL) {
            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Destination type is .file but fileURL not given or is not a FileURL"])
        }
        else if command.sourceOrDestinationType == .memory && command.data == nil {
            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Destination type is .memory, but data is nil"])
        }
        
        // Make the passive data connection.
        let dataConnection = try await makePassiveDataConnection()
        
        // Send the actual command
        try await controlConnection.sendCommand(command)
        
        // Send the data.
        return try await doActualSend(command: command, dataConnection: dataConnection)
    }
    
    private func makeActiveDataConnection() async throws -> FTPDataConnection {
        guard sessionState == .idle, let controlConnection else {
            throw FTPError(.unknown, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: No control connection or session not idle"])
        }
        
        // A system can have multiple IP addresses. For the listener IP address, we pass the IP address of the control connection.
        // The control connection is connected and has a local IP address, which means that it can reach the server, and has the
        // highest chance that the server can reach it back.
        guard let listenerIPAddress = await controlConnection.localIPAddress else {
            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: No IP address available"])
        }
        let listenerIPPort = await controlConnection.nextFreeIPPort
        
        // Set up data connection to listen.
        let dataConnection = try await FTPDataConnection(session: self)
        try await dataConnection.listen(port: listenerIPPort)
        
        // Send the PORT command with the listener address and port.
        let ftpPORTCommand = FTPPORTCommand(ipAddress: listenerIPAddress, ipPort: listenerIPPort)
        try await controlConnection.sendCommand(ftpPORTCommand)
        let ftpPORTReply = try await controlConnection.receiveReply(commandGroup: ftpPORTCommand.commandGroup)
        guard await ftpPORTReply.code == FTPResponseCodes.commandOk,
        let message = await ftpPORTReply.message else {
            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Failed to enter active mode (\(await ftpPORTReply.code ?? -1), \(await ftpPORTReply.message ?? "unknown"))"])
        }
        
        return dataConnection
    }
    
    private func makePassiveDataConnection() async throws -> FTPDataConnection {
        
        guard sessionState == .idle, let controlConnection else {
            throw FTPError(.unknown, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: No control connection or session not idle"])
        }
        
        // Send PASV command to get the ip address and port for the data connection.
        let ftpPASVCommand = FTPPASVCommand()
        try await controlConnection.sendCommand(ftpPASVCommand)
        let ftpPASVReply = try await controlConnection.receiveReply(commandGroup: ftpPASVCommand.commandGroup)
        guard await ftpPASVReply.code == FTPResponseCodes.enteringPassiveMode,
              let message = await ftpPASVReply.message else {
            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Failed to enter passive mode (\(await ftpPASVReply.code ?? -1), \(await ftpPASVReply.message ?? "unknown"))"])
        }
        let (serverIPAddress, serverIPPort) = try FTPPASVReplyParser.parse(message: message)
        
        // Make the data connection.
        let dataConnection = try await FTPDataConnection(session: self)
        try await dataConnection.connect(address: serverIPAddress, port: serverIPPort)

        return dataConnection
    }
    
    private func doActualReceive(command: some FTPCommand, dataConnection: FTPDataConnection) async throws -> FTPCommandResult {

        guard sessionState == .idle, let controlConnection else {
            throw FTPError(.unknown, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: No control connection or session not idle"])
        }
        
        var commandResult: FTPCommandResult = FTPCommandResult(code: -1, message: "Unknown error", data: nil)
        var done: Bool = false
        
        let ftpDataResult: FTPDataResult? = try await withThrowingTaskGroup(of: FTPDataResult?.self) { taskGroup in
            
            while !done {
                
                let ftpCommandReply = try await controlConnection.receiveReply(commandGroup: command.commandGroup)
                
                let replyCode = await ftpCommandReply.code ?? -1
                
                if command.commandGroup == .simpleExtended && replyCode >= 100 && replyCode < 200 {
                    
                    switch command.sourceOrDestinationType {
                    case .file:
                        if let fileURL = command.localFileURL {
                            do {
                                taskGroup.addTask { try await dataConnection.receiveToFile(fileURL: fileURL) }
                            }
                            catch {
                                commandResult = FTPCommandResult(code: FTPResponseCodes.actionAbortedInsufficientStorage,
                                                                 message: "Receiving of file failed, error: \(error)",
                                                                 data: nil)
                            }
                        }
                        else {
                            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Asked to receive a file, but no local filename was given"])
                        }
                    case .memory:
                        do {
                            taskGroup.addTask { try await dataConnection.receiveInMemory() }
                        }
                        catch {
                            commandResult = FTPCommandResult(code: FTPResponseCodes.actionAbortedInsufficientStorage,
                                                             message: "Receiving of data failed, error: \(error)",
                                                             data: nil)
                        }
                    default:
                        throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Unsupported source or destination type for .simpleExtended command"])
                    }
                }
                else if command.commandGroup != .simpleExtended && replyCode >= 100 && replyCode < 200 {
                    // This is a failure result
                    try await dataConnection.disconnect()
                    done = true
                }
                else if replyCode >= 200 && replyCode < 300 {
                    
                    // This is a success result. Return it to our caller.
                    
                    commandResult = FTPCommandResult(code: await ftpCommandReply.code,
                                                     message: await ftpCommandReply.message,
                                                     data: nil)
                    done = true
                }
                else {
                    
                    // This is a failure result. Return it to our caller.
                    
                    // NOTE: This is doing the same as the success result, but we keep it separate for now
                    // NOTE: for testing purposes.
                    
                    commandResult = FTPCommandResult(code: await ftpCommandReply.code,
                                                     message: await ftpCommandReply.message,
                                                     data: nil)
                    done = true
                }
            }
            
            // Wait for data  to have arrived, and return.
            var ftpDataResult: FTPDataResult?
            for try await result in taskGroup {
                ftpDataResult = result
            }
            
            return ftpDataResult
        }
        
        await commandResult.setData(ftpDataResult)
        
        return commandResult
    }
    

    
    private func doActualSend(command: some FTPCommand, dataConnection: FTPDataConnection) async throws -> FTPCommandResult {
        
        guard sessionState == .idle, let controlConnection else {
            throw FTPError(.unknown, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: No control connection or session not idle"])
        }
        
        var commandResult: FTPCommandResult = FTPCommandResult(code: -1, message: "Unknown error", data: nil)
        var done: Bool = false

        while !done {
            let ftpCommandReply = try await controlConnection.receiveReply(commandGroup: command.commandGroup)
            
            // TODO: We should really be stepping through a state machine base on the reply codes. Now
            // TODO: we just check reply code groups and execute commands based on if there is an error
            // TODO: or not. But the reply codes are more subtle than that, and now we can't apply that
            // TODO: subtlety. This should not be hardcoded.
            
            // TODO: For now this is not the best implementation. It works, but it should be the FTPxxxCommand's
            // TODO: responsibility to decide what is a 'good' replyCode or a 'bad' replyCode.
            
            // TODO: Maybe we can have a function 'nextStep(for: replyCode' in the FTPxxxCommands. That function
            // TODO: can then return steps like 'startUpload', 'startDownload', 'reportError', 'continue', etc,
            // TODO: instructing this functions to do things, while the decision logic will be inside the
            // TODO: FTPxxxCommand.
            
            let replyCode = await ftpCommandReply.code ?? -1
            
            if command.commandGroup == .simpleExtended && replyCode >= 100 && replyCode < 200 {
                // This is an intermediate result returned by a .simpleExtended command.
                switch command.sourceOrDestinationType {
                case .file:
                    if let fileURL = command.localFileURL {
                        do {
                            try await dataConnection.send(fileURL)
                        }
                        catch {
                            commandResult = FTPCommandResult(code: FTPResponseCodes.actionAbortedInsufficientStorage,
                                                             message: "Sending of file failed, error: \(error)",
                                                             data: nil)
                        }
                    }
                    else {
                        throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Asked to send a file, but no filename was given"])
                    }
                case .memory:
                    if let data = command.data {
                        do {
                            try await dataConnection.send(data)
                        }
                        catch {
                            commandResult = FTPCommandResult(code: FTPResponseCodes.actionAbortedInsufficientStorage,
                                                             message: "Sending of data failed, error: \(error)",
                                                             data: nil)
                        }
                    }
                    else {
                        throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Asked to send data, but no data was given"])
                    }
                default:
                    throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Unsupported source or destination type for .simpleExtended command"])
                }
            }
            else if command.commandGroup != .simpleExtended && replyCode >= 100 && replyCode < 200 {
                // This is a failure result
                try await dataConnection.disconnect()
                done = true
            }
            else if replyCode >= 200 && replyCode < 300 {
                // This is a success result. Return it to our caller.
                commandResult = FTPCommandResult(code: await ftpCommandReply.code,
                                                 message: await ftpCommandReply.message,
                                                 data: nil)
                done = true
            }
            else {
                // This is a failure result. Return it to our caller.
                commandResult = FTPCommandResult(code: await ftpCommandReply.code,
                                                 message: await ftpCommandReply.message,
                                                 data: nil)
                done = true
            }
        }

        return commandResult
    }
}
