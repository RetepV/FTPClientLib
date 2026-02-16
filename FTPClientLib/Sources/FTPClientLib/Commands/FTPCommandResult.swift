//
//  FTPCommandResult.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 02-01-2026.
//

import Foundation

final actor FTPCommandResult : Sendable {
    
    var code: Int = -1
    var message: String?
    
    var data: FTPDataResult?
    
    init(code: Int, message: String? = nil, data: FTPDataResult? = nil) {
        self.code = code
        self.message = message
        
        self.data = data
    }
    
    func setData(_ data: FTPDataResult?) {
        self.data = data
    }
}
