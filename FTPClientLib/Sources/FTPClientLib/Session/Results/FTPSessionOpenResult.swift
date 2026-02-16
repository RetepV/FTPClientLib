//
//  FTPOpenConnectionResult.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 19-12-2025.
//

public actor FTPSessionOpenResult {
    
    public enum Result {
        case unknown
        case success
        case failure
    }

    public let result: Result
    
    public let code: Int?
    public let welcomeMessage: String?
    
    init(result: Result, code: Int?, welcomeMessage: String? = nil) {
        self.result = result
        
        self.code = code
        self.welcomeMessage = welcomeMessage
    }
}
