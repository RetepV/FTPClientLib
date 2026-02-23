//
//  FTPSessionList.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 30-12-2025.
//

import Foundation

extension FTPClientSession {
    
    // MARK; - Public
    
    public func list(path: String? = nil) async throws -> FTPSessionLISTResult {
        
        guard sessionState == .idle, controlConnection != nil else {
            Self.logger.info("Trying to fetch directory of a session that is not open")
            throw FTPError(.notOpened, userinfo: [NSLocalizedDescriptionKey : "FTPClientSession: Session not idle"])
        }
        
        await commandExecutionLock.wait()
        defer {commandExecutionLock.signal()}

        let ftpLISTCommandResult = try await performCommand(FTPLISTCommand(path: path))

        switch await ftpLISTCommandResult.code {
            
            // -=- fileStatusOK should not be handled here, or at least should not cause us to return a result yet, because we will
            // -=- receive more, and should only stop on 2xx results.
            // -=- But the performCommand should already have not returned the 150 in the first place. This is for ACTIVE mode.
            
        case FTPResponseCodes.fileStatusOK,
            FTPResponseCodes.fileActionCompleted,
            FTPResponseCodes.requestedFileActionOk:
            
            if let directoryData = try await ftpLISTCommandResult.data?.data,
               let directoryString = String(data: directoryData, encoding: .utf8) {
               
                let fileList = try FTPLISTReplyParser.parse(message: directoryString)
                
                return FTPSessionLISTResult(result: FTPSessionLISTResult.Result.success,
                                           code: await ftpLISTCommandResult.code,
                                           message: await ftpLISTCommandResult.message,
                                           files: fileList)
            }
            
            // Return success, but empty files list.
            return FTPSessionLISTResult(result: FTPSessionLISTResult.Result.success,
                                       code: await ftpLISTCommandResult.code,
                                       message: await ftpLISTCommandResult.message,
                                       files: nil)

        default:
            return FTPSessionLISTResult(result: FTPSessionLISTResult.Result.failure,
                                        code: await ftpLISTCommandResult.code,
                                        message: await ftpLISTCommandResult.message,
                                        files: nil)
        }
    }
}

