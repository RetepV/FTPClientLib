//
//  FTPDataResult.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 04-01-2026.
//

import Foundation

final actor FTPDataResult : Sendable {
    
    let size: Int

    let data: Data?
    let fileURL: URL?
        
    init(size: Int, data: Data? = nil, fileURL: URL? = nil) {
        self.size = size
        self.data = data
        self.fileURL = fileURL
    }
}
