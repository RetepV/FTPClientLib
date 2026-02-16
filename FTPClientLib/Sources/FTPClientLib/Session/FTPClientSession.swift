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
        
        guard sessionState == .opened, controlConnection != nil else {
            Self.logger.info("FTPClientSession: Trying to close a session that is not open")
            throw FTPError(.notOpened, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Session not opened"])
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
        
        guard sessionState == .opened, let controlConnection else {
            throw FTPError(.unknown, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: No control connection"])
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
        
        guard sessionState == .opened, let controlConnection else {
            throw FTPError(.unknown, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: No control connection"])
        }
        
        guard let commandString = command.commandString, commandString.isEmpty == false else {
            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Empty or no commandString"])
        }
        
        guard command.sourceOrDestinationType != .none else {
            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Source or destination should not be .none here"])
        }
        
        // For the listener IP address, we pass the IP address of the control connection. The control connection
        // is connected and has a local IP address, which means that it can reach the server, and has the highest
        // chance that the server can reach it back.
        guard let listenerIPAddress = await controlConnection.localIPAddress else {
            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: No IP address available"])
        }
        let listenerIPPort = await controlConnection.nextFreeIPPort
        
        // Set up data connection for listening. This must be done before sending the PORT command, so
        // that we have already reserved the IP port. We only start listening, we only wait for a connection
        // after having sent the actual command.
        
        let dataConnection = try await FTPDataConnection(session: self)
        try await dataConnection.listen(port: listenerIPPort)
        
        // Send the PORT command.
        
        let ftpPORTCommand = FTPPORTCommand(ipAddress: listenerIPAddress, ipPort: listenerIPPort, chainedCommand: command)
        try await controlConnection.sendCommand(ftpPORTCommand)
        
        let ftpPORTReply = try await controlConnection.receiveReply(commandGroup: command.commandGroup)
        
        guard await ftpPORTReply.code == FTPResponseCodes.commandOk,
              let message = await ftpPORTReply.message else {
            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Failed to enter active mode (\(await ftpPORTReply.code ?? -1), \(await ftpPORTReply.message ?? "unknown"))"])
        }
        
        // Send the actual command.
        
        try await controlConnection.sendCommand(command)
        try await dataConnection.waitForConnection(timeout: FTPClientLibDefaults.timeoutInSecondsForListen)
                
        // TODO: There is a bunch of code duplication here because of the use of 'async let'.
        // TODO: Maybe a taskGroup would make for nicer code?

        var commandResult: FTPCommandResult = .init(code: 0, message: nil, data: nil)

        if command.sourceOrDestinationType == .file, let fileURL = command.fileURL {
            async let ftpCommandReply = try await controlConnection.receiveReply(commandGroup: command.commandGroup)
            async let ftpDataReply = try await dataConnection.receiveToFile(fileURL: fileURL)
            
            commandResult = FTPCommandResult(code: try await ftpCommandReply.code,
                                             message: try await ftpCommandReply.message,
                                             data: try await ftpDataReply)
        }
        else if command.sourceOrDestinationType == .memory {
            async let ftpCommandReply = try await controlConnection.receiveReply(commandGroup: command.commandGroup)
            async let ftpDataReply = try await dataConnection.receiveInMemory()
            
            commandResult = FTPCommandResult(code: try await ftpCommandReply.code,
                                             message: try await ftpCommandReply.message,
                                             data: try await ftpDataReply)
        }
        
        return commandResult
    }
    
    private func doReceiveWithPassiveDataConnection(_ command: some FTPCommand) async throws -> FTPCommandResult {
        
        guard sessionState == .opened, let controlConnection else {
            throw FTPError(.unknown, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: No control connection"])
        }
        
        guard let commandString = command.commandString, commandString.isEmpty == false else {
            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Empty or no commandString"])
        }
        
        let ftpPASVCommand = FTPPASVCommand(chainedCommand: command)
        try await controlConnection.sendCommand(ftpPASVCommand)
        
        let ftpPASVReply = try await controlConnection.receiveReply(commandGroup: command.commandGroup)
        guard await ftpPASVReply.code == FTPResponseCodes.enteringPassiveMode,
              let message = await ftpPASVReply.message else {
            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Failed to enter passive mode (\(await ftpPASVReply.code ?? -1), \(await ftpPASVReply.message ?? "unknown"))"])
        }
        let (serverIPAddress, serverIPPort) = try FTPPASVReplyParser.parse(message: message)
        
        let dataConnection = try await FTPDataConnection(session: self)
        
        try await dataConnection.connect(address: serverIPAddress, port: serverIPPort)
        
        try await controlConnection.sendCommand(command)
        
        
        // TODO: There is a bunch of code duplication here because of the use of 'async let'.
        // TODO: Maybe a taskGroup would make for nicer code?
                
        
        var commandResult: FTPCommandResult = FTPCommandResult(code: -1, message: "Unknown error", data: nil)
        var done: Bool = false
        
        let ftpDataResult: FTPDataResult? = try await withThrowingTaskGroup(of: FTPDataResult?.self) { taskGroup in
            
            while !done {
                
                let ftpCommandReply = try await controlConnection.receiveReply(commandGroup: command.commandGroup)
                
                let replyCode = await ftpCommandReply.code ?? -1
                
                if command.commandGroup == .simpleExtended && replyCode >= 100 && replyCode < 200 {
                    
                    switch command.sourceOrDestinationType {
                    case .file:
                        if let fileURL = command.fileURL {
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
                            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Asked to send a file, but no filename was given"])
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
    
    private func doSendWithActiveDataConnection(_ command: some FTPCommand) async throws -> FTPCommandResult {
        
        guard sessionState == .opened, let controlConnection else {
            throw FTPError(.unknown, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: No control connection"])
        }
        
        guard let commandString = command.commandString, commandString.isEmpty == false else {
            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Empty or no commandString"])
        }
        
        // For the listener IP address, we pass the IP address of the control connection. The control connection
        // is connected and has a local IP address, which means that it can reach the server, and has the highest
        // chance that the server can reach it back.
        guard let listenerIPAddress = await controlConnection.localIPAddress else {
            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: No IP address available"])
        }
        let listenerIPPort = await controlConnection.nextFreeIPPort
        
        // Set up data connection for listening. This must be done before sending the PORT command, so
        // that we have already reserved the IP port. We only start listening, we only wait for a connection
        // after having sent the actual command.
        
        let dataConnection = try await FTPDataConnection(session: self)
        try await dataConnection.listen(port: listenerIPPort)

        // Send the PORT command.
        
        let ftpPORTCommand = FTPPORTCommand(ipAddress: listenerIPAddress, ipPort: listenerIPPort, chainedCommand: command)
        try await controlConnection.sendCommand(ftpPORTCommand)

        let ftpPORTReply = try await controlConnection.receiveReply(commandGroup: command.commandGroup)
        
        guard await ftpPORTReply.code == FTPResponseCodes.commandOk,
        let message = await ftpPORTReply.message else {
            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Failed to enter active mode (\(await ftpPORTReply.code ?? -1), \(await ftpPORTReply.message ?? "unknown"))"])
        }

        // Send the actual command.
        
        try await controlConnection.sendCommand(command)
        try await dataConnection.waitForConnection(timeout: FTPClientLibDefaults.timeoutInSecondsForListen)
        
        var commandResult: FTPCommandResult = .init(code: 0, message: nil, data: nil)

        if command.sourceOrDestinationType == .file, let fileURL = command.fileURL {
            async let ftpCommandReply = try await controlConnection.receiveReply(commandGroup: command.commandGroup)
            async let _ = try await dataConnection.send(fileURL)

            commandResult = FTPCommandResult(code: try await ftpCommandReply.code,
                                             message: try await ftpCommandReply.message,
                                             data: nil)
        }
        else if command.sourceOrDestinationType == .memory, let data = command.data {
            async let ftpCommandReply = try await controlConnection.receiveReply(commandGroup: command.commandGroup)
            async let _ = try await dataConnection.send(data)
            
            commandResult = FTPCommandResult(code: try await ftpCommandReply.code,
                                             message: try await ftpCommandReply.message,
                                             data: nil)
        }
        
        return commandResult
    }

    private func doSendWithPassiveDataConnection(_ command: some FTPCommand) async throws -> FTPCommandResult {
        
        guard sessionState == .opened, let controlConnection else {
            throw FTPError(.unknown, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: No control connection"])
        }
        
        guard let commandString = command.commandString, commandString.isEmpty == false else {
            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Empty or no commandString"])
        }
        
        if command.sourceOrDestinationType == .file && (command.fileURL == nil || !command.fileURL!.isFileURL) {
            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Destination type is .file but fileURL not given or is not a FileURL"])
        }
        else if command.sourceOrDestinationType == .memory && command.data == nil {
            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Destination type is .memory, but data is nil"])
        }

        let ftpPASVCommand = FTPPASVCommand(chainedCommand: command)
        try await controlConnection.sendCommand(ftpPASVCommand)
        
        let ftpPASVReply = try await controlConnection.receiveReply(commandGroup: command.commandGroup)
        guard await ftpPASVReply.code == FTPResponseCodes.enteringPassiveMode,
        let message = await ftpPASVReply.message else {
            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Failed to enter passive mode (\(await ftpPASVReply.code ?? -1), \(await ftpPASVReply.message ?? "unknown"))"])
        }
        let (serverIPAddress, serverIPPort) = try FTPPASVReplyParser.parse(message: message)
        
        let dataConnection = try await FTPDataConnection(session: self)
        
        try await dataConnection.connect(address: serverIPAddress, port: serverIPPort)

        try await controlConnection.sendCommand(command)

        var commandResult: FTPCommandResult = FTPCommandResult(code: -1, message: "Unknown error", data: nil)
        var done: Bool = false

        while !done {
            
            // DONE.
            
            let ftpCommandReply = try await controlConnection.receiveReply(commandGroup: command.commandGroup)
            
            // For 'simpleExtended', a reply code in the range of [100..<200] is valid.
            
            // TODO: The reply codes should really cause us to step through a state machine. The state
            // TODO: machine differs between commands, and should not be hardcoded here.
            // TODO:
            // TODO: Maybe we can define a bunch of fixed states, put a 'nextState' function in every
            // TODO: FTPxxxCommand, and so control steppingthrough the different states necessary for
            // TODO: different commands? It does make a bit of sense, in terms of responsibility.
            // TODO: It does mean that the call to `receiveReply` has to return exactly one reply at a
            // TODO: time, which might need changes to the parser.
            // TODO: Can we do these things in a nice Swift Concurrency type of way?
            
            // TODO: For now this is a bad implementation, just for testing purposes.
            
            let replyCode = await ftpCommandReply.code ?? -1
            
            if command.commandGroup == .simpleExtended && replyCode >= 100 && replyCode < 200 {
                
                // This is an intermediate result returned by a .simpleExtended command.
                
                switch command.sourceOrDestinationType {
                case .file:
                    if let fileURL = command.fileURL {
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
                
                // NOTE: This is doing the same as the success result, but we keep it separate for now
                // NOTE: for testing purposes.
                
                commandResult = FTPCommandResult(code: await ftpCommandReply.code,
                                                 message: await ftpCommandReply.message,
                                                 data: nil)
                done = true
            }
        }

        return commandResult
    }
}
