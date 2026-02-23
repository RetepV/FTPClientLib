//
//  FTPSessionRETR.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 09-01-2026.
//

import Foundation

extension FTPClientSession {
    
    // MARK; - Public
    
    public func retrieveFile(fileURL: URL, remotePath: String? = nil) async throws -> FTPSessionRETRResult {
        
        guard sessionState == .idle, controlConnection != nil else {
            Self.logger.info("Trying to retrieve a file for a session that is not idle")
            throw FTPError(.notOpened, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Session not idle"])
        }
        
        await commandExecutionLock.wait()
        defer {commandExecutionLock.signal()}
        
        Self.logger.info("retrieveFile fileURL: \(fileURL), remotePath: \(String(describing: remotePath))")
        
        let ftpRETRCommandResult = try await performCommand(FTPRETRCommand(remotePath: remotePath ?? fileURL.lastPathComponent,
                                                                           localFileURL: fileURL))

        switch await ftpRETRCommandResult.code {
        case FTPResponseCodes.fileActionCompleted, FTPResponseCodes.requestedFileActionOk:
            
            return FTPSessionRETRResult(result: .success,
                                        code: await ftpRETRCommandResult.code,
                                        message: await ftpRETRCommandResult.message)
            
        default:
            return FTPSessionRETRResult(result: .failure,
                                        code: await ftpRETRCommandResult.code,
                                        message: await ftpRETRCommandResult.message)
        }
    }
}

