//
//  FTPSessionQUIT.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 30-12-2025.
//

import Foundation

extension FTPClientSession {
    
    // MARK; - Public
    
    public func logout() async throws -> FTPSessionQUITResult {
        
        guard sessionState == .opened, controlConnection != nil else {
            Self.logger.info("Trying to log a user out of a session that is not open")
            throw FTPError(.notOpened, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Session not open"])
        }
        
        await commandExecutionLock.wait()
        defer {commandExecutionLock.signal()}

        let ftpQUITCommandResult = try await performCommand(FTPQUITCommand())

        switch await ftpQUITCommandResult.code {
        case FTPResponseCodes.requestedFileActionOk:
            
            return FTPSessionQUITResult(result: .success,
                                       code: await ftpQUITCommandResult.code,
                                       message: await ftpQUITCommandResult.message)

        default:
            return FTPSessionQUITResult(result: .failure,
                                       code: await ftpQUITCommandResult.code,
                                       message: await ftpQUITCommandResult.message)
        }
    }
}

