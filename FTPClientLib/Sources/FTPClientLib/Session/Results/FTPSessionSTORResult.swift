//
//  FTPSessionSTORResult.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 19-12-2025.
//

public actor FTPSessionSTORResult: Sendable {
    
    public enum Result: Sendable {
        case unknown
        case success
        case failure
    }

    public let result: Result
    
    public let code: Int?
    public let message: String?
    
    init(result: Result, code: Int?, message: String? = nil) {
        self.result = result
        
        self.code = code
        self.message = message
    }
}
