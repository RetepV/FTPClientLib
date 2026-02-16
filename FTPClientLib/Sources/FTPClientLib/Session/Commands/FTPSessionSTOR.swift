//
//  FTPSessionSTOR.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 09-01-2026.
//

import Foundation

extension FTPClientSession {
    
    // MARK; - Public
    
    public func storeFile(fileURL: URL) async throws -> FTPSessionSTORResult {
        
        guard sessionState == .opened, controlConnection != nil else {
            Self.logger.info("Trying to change directory for a session that is not open")
            throw FTPError(.notOpened, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Session not open"])
        }
        
        await commandExecutionLock.wait()
        defer {commandExecutionLock.signal()}
        
        let ftpSTORCommandResult = try await performCommand(FTPSTORCommand(fileURL: fileURL))

        switch await ftpSTORCommandResult.code {
        case FTPResponseCodes.fileActionCompleted, FTPResponseCodes.requestedFileActionOk:
            
            return FTPSessionSTORResult(result: .success,
                                        code: await ftpSTORCommandResult.code,
                                        message: await ftpSTORCommandResult.message)
            
        default:
            return FTPSessionSTORResult(result: .failure,
                                        code: await ftpSTORCommandResult.code,
                                        message: await ftpSTORCommandResult.message)
        }
    }
}

