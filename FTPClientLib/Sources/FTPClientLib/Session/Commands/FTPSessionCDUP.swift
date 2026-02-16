//
//  FTPSessionCDUP.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 30-12-2025.
//

import Foundation

extension FTPClientSession {
    
    // MARK; - Public
    
    public func changeToParentDirectory() async throws -> FTPSessionCDUPResult {
        
        guard sessionState == .opened, controlConnection != nil else {
            Self.logger.info("Trying to change to parent directory for a session that is not open")
            throw FTPError(.notOpened, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Session not open"])
        }
        
        await commandExecutionLock.wait()
        defer {commandExecutionLock.signal()}

        let ftpCDUPCommandResult = try await performCommand(FTPCDUPCommand())

        switch await ftpCDUPCommandResult.code {
        case FTPResponseCodes.requestedFileActionOk:
            
            return FTPSessionCDUPResult(result: .success,
                                       code: await ftpCDUPCommandResult.code,
                                       message: await ftpCDUPCommandResult.message)

        default:
            return FTPSessionCDUPResult(result: .failure,
                                       code: await ftpCDUPCommandResult.code,
                                       message: await ftpCDUPCommandResult.message)
        }
    }
}

