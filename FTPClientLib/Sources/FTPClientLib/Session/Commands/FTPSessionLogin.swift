//
//  FTPSessionLogin.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 30-12-2025.
//

import Foundation

extension FTPClientSession {
    
    // MARK; - Public
    
    public func login(username: String, password: String, account: String? = nil) async throws -> FTPSessionLoginResult {

        guard sessionState == .opened, controlConnection != nil else {
            Self.logger.info("Trying to login with a session that is not open")
            throw FTPError(.notOpened, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Session not open"])
        }
        
        await commandExecutionLock.wait()
        defer {commandExecutionLock.signal()}

        let result = try await performUSERCommand(username: username, password: password, account: account)
        
        if result.result == .success {
            sessionState = .idle
        }
        else {
            sessionState = .failed(FTPError(.loginFailed, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Login failed: \(result.message)"]))
        }

        return result
    }
    
    private func performUSERCommand(username: String, password: String, account: String?) async throws -> FTPSessionLoginResult {
        
        let ftpUSERCommandResult = try await performCommand(FTPUSERCommand(username: username))

        switch await ftpUSERCommandResult.code {
        case FTPResponseCodes.userLoggedIn:
            return FTPSessionLoginResult(result: FTPSessionLoginResult.Result.success,
                                         code: await FTPResponseCodes.userLoggedIn,
                                         message: await ftpUSERCommandResult.message)

        case FTPResponseCodes.userNameOkNeedsPassword:
            return try await performPASSCommand(password: password, account: account)

        case FTPResponseCodes.needAccountForLogin:
            if let account {
                return try await performACCTCommand(account: account)
            }
            return FTPSessionLoginResult(result: FTPSessionLoginResult.Result.accountFailure,
                                         code: await ftpUSERCommandResult.code,
                                         message: await ftpUSERCommandResult.message)

        default:
            return FTPSessionLoginResult(result: FTPSessionLoginResult.Result.usernameFailure,
                                         code: await ftpUSERCommandResult.code,
                                         message: await ftpUSERCommandResult.message)
        }
    }
    
    private func performPASSCommand(password: String, account: String?) async throws -> FTPSessionLoginResult {
        
        let ftpPASSCommandResult = try await performCommand(FTPPASSCommand(password: password))

        switch await ftpPASSCommandResult.code {
            
        case FTPResponseCodes.userLoggedIn,
            FTPResponseCodes.commandNotImplementedSuperfluousAtThisSite:
            // Password was accepted or not necessary, user is logged in.
            return FTPSessionLoginResult(result: FTPSessionLoginResult.Result.success,
                                         code: FTPResponseCodes.userLoggedIn,
                                         message: await ftpPASSCommandResult.message)

        case FTPResponseCodes.needAccountForLogin:
            if let account {
                return try await performACCTCommand(account: account)
            }
            return FTPSessionLoginResult(result: FTPSessionLoginResult.Result.accountFailure,
                                         code: await ftpPASSCommandResult.code,
                                         message: await ftpPASSCommandResult.message)

        default:
            return FTPSessionLoginResult(result: FTPSessionLoginResult.Result.passwordFailure,
                                         code: await ftpPASSCommandResult.code,
                                         message: await ftpPASSCommandResult.message)
        }
    }

    private func performACCTCommand(account: String) async throws -> FTPSessionLoginResult {
        
        let ftpACCTCommandResult = try await performCommand(FTPACCTCommand(account: account))

        switch await ftpACCTCommandResult.code {
        case FTPResponseCodes.userLoggedIn,
            FTPResponseCodes.commandNotImplementedSuperfluousAtThisSite:
            // Account was accepted or not necessary, user is logged in.
            return FTPSessionLoginResult(result: FTPSessionLoginResult.Result.success,
                                         code: await ftpACCTCommandResult.code,
                                         message: await ftpACCTCommandResult.message)
            
        default:
            return FTPSessionLoginResult(result: FTPSessionLoginResult.Result.accountFailure,
                                         code: await ftpACCTCommandResult.code,
                                         message: await ftpACCTCommandResult.message)
        }
    }
}

