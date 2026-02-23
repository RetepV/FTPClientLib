//
//  FTPSessionNOOP.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 30-12-2025.
//

import Foundation

extension FTPClientSession {
    
    // MARK; - Public
    
    public func noOperation() async throws -> FTPSessionNOOPResult {
        
        guard sessionState == .idle, controlConnection != nil else {
            Self.logger.info("Trying to send a no-operation for a session that is not idle")
            throw FTPError(.notOpened, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Session not idle"])
        }
        
        await commandExecutionLock.wait()
        defer {commandExecutionLock.signal()}

        let ftpNOOPCommandResult = try await performCommand(FTPNOOPCommand())

        switch await ftpNOOPCommandResult.code {
        case FTPResponseCodes.requestedFileActionOk, FTPResponseCodes.pathNameCreated:
            return FTPSessionNOOPResult(result: .success,
                                        code: await ftpNOOPCommandResult.code,
                                        message: await ftpNOOPCommandResult.message)

        default:
            return FTPSessionNOOPResult(result: .failure,
                                        code: await ftpNOOPCommandResult.code,
                                        message: await ftpNOOPCommandResult.message)
        }
    }
}

