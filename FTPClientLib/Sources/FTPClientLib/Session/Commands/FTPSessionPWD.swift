//
//  FTPSessionPWD.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 30-12-2025.
//

import Foundation

extension FTPClientSession {
    
    // MARK; - Public
    
    public func printWorkingDirectory() async throws -> FTPSessionPWDResult {
        
        guard sessionState == .opened, controlConnection != nil else {
            Self.logger.info("Trying to fetch current working directory of a session that is not open")
            throw FTPError(.notOpened, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Session not open"])
        }
        
        await commandExecutionLock.wait()
        defer {commandExecutionLock.signal()}

        let ftpPWDCommandResult = try await performCommand(FTPPWDCommand())

        switch await ftpPWDCommandResult.code {
        case FTPResponseCodes.pathNameCreated:
            
            return FTPSessionPWDResult(result: .success,
                                       code: await ftpPWDCommandResult.code,
                                       workingDirectory: await ftpPWDCommandResult.message)

        default:
            return FTPSessionPWDResult(result: .failure,
                                       code: await ftpPWDCommandResult.code,
                                       workingDirectory: await ftpPWDCommandResult.message)
        }
    }
}

