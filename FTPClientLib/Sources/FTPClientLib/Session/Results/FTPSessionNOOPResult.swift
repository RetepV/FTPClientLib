//
//  FTPSessionNOOPResult.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 23-2-20256
//

public actor FTPSessionNOOPResult {
    
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
