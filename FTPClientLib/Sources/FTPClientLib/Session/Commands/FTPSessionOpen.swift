//
//  FTPSessionOpen.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 19-12-2025.
//

import Foundation

extension FTPClientSession {
    
    public func open(timeout: TimeInterval = FTPClientLibDefaults.timeoutInSecondsForConnection) async throws -> FTPSessionOpenResult {

        Self.logger.trace("FTPClientSession: Opening control connection to \(self.controlConnectionURL)")
        
        guard sessionState == .initialised || sessionState == .closed || ({if case .failed = sessionState {true} else {false}}()) else {
            Self.logger.error("FTPClientSession: Error opening control connection, wrong session state: \(self.sessionState.rawValue)")
            throw FTPError(.notInitialised, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Not initialised, closed or failed"])
        }
        
        guard controlConnectionURL.scheme == "ftp" else {
            let error = FTPError(.notConnected, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: URL is not an FTP url: \(controlConnectionURL)"])
            sessionState = .failed(error)
            throw error
        }
        guard controlConnectionURL.port != nil else {
            let error = FTPError(.notConnected, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: URL does not provide a port: \(controlConnectionURL)"])
            sessionState = .failed(error)
            throw error
        }

        sessionState = .opening

        try await createControlConnection()
        
        guard let controlConnection else {
            let error = FTPError(.notConnected, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Control connection is unexpectedly nil"])
            throw error
        }
        
        try await connect()
        
        let controlConnectionState = try await controlConnection.connectionState

        var connectionResult: FTPCommandResult? = nil
        if controlConnectionState == .connected {
            do {
                connectionResult = try await readWelcomeMessage()
            }
            catch {
                let error = FTPError(.notConnected, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Failed to read welcome message. Error: \(error)"])
                throw error
            }
        }
        
        guard let connectionResult else {
            let error = FTPError(.notConnected, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Failed to read welcome message."])
            throw error
        }
        
        var result: FTPSessionOpenResult.Result = .unknown

        switch controlConnectionState {
        case .connected:
            Self.logger.trace("FTPClientSession:Control connection to \(self.controlConnectionURL) is open")
            sessionState = .opened
            result = .success
        case .disconnected:
            Self.logger.error("FTPClientSession: Control connection to \(self.controlConnectionURL) failed for an unknown reason")
            sessionState = .failed(FTPError.unknownError(message: "After controlConnection connection attempt, state was .disconnected"))
            result = .failure
        case .failed(let error):
            Self.logger.error("FTPClientSession: Control connection to \(self.controlConnectionURL) failed. Error: \(error)")
            sessionState = .failed(error)
            result = .failure
        default:
            fatalError("FTPClientSession: Unexpected state \(controlConnectionState), check why this is happening.")
        }

        return FTPSessionOpenResult(result: result, code: await connectionResult.code, welcomeMessage: await connectionResult.message)
    }
    
    // MARK: - Private
    
    private func createControlConnection() async throws {
        do {
            controlConnection = try await .init(session: self)
        }
        catch {
            let error = FTPError(.notConnected, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Failed to create control connection: \(error)"])
            sessionState = .failed(error)
            throw error
        }
    }
    
    private func connect() async throws {
        
        do {
            try await controlConnection?.connect()
        }
        catch {
            let error = FTPError(.notConnected, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Failed to connect. Error: \(error)"])
            sessionState = .failed(error)
            throw error
        }
    }

    private func readWelcomeMessage() async throws -> FTPCommandResult {
        
        guard let controlConnection else {
            let error = FTPError(.notConnected, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Control connection is unexpectedly nil"])
            sessionState = .failed(error)
            throw error
        }
        
        do {
            return try await controlConnection.receiveReply(commandGroup: FTPCommandGroup.simple)
        }
        catch {
            let error = FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Failed to read welcome message. Error: \(error)"])
            sessionState = .failed(error)
            throw error
        }
    }
}
