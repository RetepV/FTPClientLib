//
//  FTPError.swift
//  FTPClient
//
//  Created by Peter de Vroomen on 06-02-2025.
//

import Foundation

public struct FTPError: Error, CustomDebugStringConvertible {
    
    public enum FTPErrorCode: Int {
        case notInitialised

        case notImplemented

        case badURL
        
        case notConnected
        case notOpened
        
        case connectionFailed
        
        case loginFailed
        
        case commandFailed

        case credentialsFailed

        case directoryNotFound

        case parseResponseFailed
        
        case fileOpenFailed
        case fileReadFailed
        case fileWriteFailed

        case unknown
    }
    
    private(set) var code: FTPErrorCode
    private(set) var userinfo: [String : Any] = [:]
    
    public var debugDescription: String {
        "FTPError: code \(code), userinfo description: \((userinfo[NSLocalizedDescriptionKey] as? String) as String?)"
    }

    public init(_ code: FTPErrorCode, userinfo: [String : Any] = [:]) {
        self.code = code
        self.userinfo = userinfo
    }
    
    public static func unknownError(message: String = "unknown error") -> FTPError {
        .init(.unknown, userinfo: [NSLocalizedDescriptionKey : message])
    }
}

enum FTPErrorMessage: String {
    
    case unknownError = "Unknown error"
    
    case sessionNotInitialisedClosedOrFailed = "FTPClientSession: Not initialised, closed or failed"

}
