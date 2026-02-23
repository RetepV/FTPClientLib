//
//  FTPSessionTYPEResult.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 21-2-2026.
//

public actor FTPSessionTYPEResult {
    
    public enum Result {
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
