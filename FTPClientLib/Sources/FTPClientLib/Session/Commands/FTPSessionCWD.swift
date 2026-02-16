//
//  FTPSessionList.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 30-12-2025.
//

import Foundation

extension FTPClientSession {
    
    // MARK; - Public
    
    public func changeWorkingDirectory(directory: String) async throws -> FTPSessionCWDResult {
        
        guard sessionState == .opened, controlConnection != nil else {
            Self.logger.info("Trying to change directory for a session that is not open")
            throw FTPError(.notOpened, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Session not opened"])
        }
        
        await commandExecutionLock.wait()
        defer {commandExecutionLock.signal()}
        
        let ftpCWDCommandResult = try await performCommand(FTPCWDCommand(directory: directory))

        switch await ftpCWDCommandResult.code {
        case FTPResponseCodes.requestedFileActionOk:
            
            return FTPSessionCWDResult(result: .success,
                                       code: await ftpCWDCommandResult.code,
                                       message: await ftpCWDCommandResult.message)

        default:
            return FTPSessionCWDResult(result: .failure,
                                       code: await ftpCWDCommandResult.code,
                                       message: await ftpCWDCommandResult.message)
        }
    }
}

