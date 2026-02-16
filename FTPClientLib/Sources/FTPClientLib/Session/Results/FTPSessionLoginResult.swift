//
//  FTPLoginResult.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 19-12-2025.
//

public actor FTPSessionLoginResult {

    public enum Result: Sendable {
        case unknown
        case success
        case usernameFailure
        case passwordFailure
        case accountFailure
    }
    
    public let result: Result
    
    public let code: Int?
    public let message: String?
    
    init(result: Result, code: Int?, message: String?) {
        self.result = result
        
        self.code = code
        self.message = message
    }

}
