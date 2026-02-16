//
//  FTPSessionPWDResult.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 19-12-2025.
//

public actor FTPSessionPWDResult {

    public enum Result: Sendable {
        case unknown
        case failure
        case success
    }
    
    public let result: Result
    
    public let code: Int?
    public let workingDirectory: String?
    
    init(result: Result, code: Int?, workingDirectory: String?) {
        self.result = result
        
        self.code = code
        self.workingDirectory = workingDirectory
    }
}
