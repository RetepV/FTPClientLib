//
//  FTPSessionCDUP.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 30-12-2025.
//

import Foundation

extension FTPClientSession {
    
    // MARK; - Public
    
    public func setType(_ type: FTPTypeCode) async throws -> FTPSessionTYPEResult {
        
        guard sessionState == .idle, controlConnection != nil else {
            Self.logger.info("Trying to change to parent directory for a session that is not idle")
            throw FTPError(.notOpened, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Session not idle"])
        }
        
        await commandExecutionLock.wait()
        defer {commandExecutionLock.signal()}

        let ftpTYPECommandResult = try await performCommand(FTPTYPECommand(type))

        switch await ftpTYPECommandResult.code {
        case FTPResponseCodes.commandOk:
            
            return FTPSessionTYPEResult(result: .success,
                                       code: await ftpTYPECommandResult.code,
                                       message: await ftpTYPECommandResult.message)

        default:
            return FTPSessionTYPEResult(result: .failure,
                                       code: await ftpTYPECommandResult.code,
                                       message: await ftpTYPECommandResult.message)
        }
    }
}

