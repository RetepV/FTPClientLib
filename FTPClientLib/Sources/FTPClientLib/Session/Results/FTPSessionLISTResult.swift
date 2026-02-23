//
//  FTPSessionLISTResult.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 19-12-2025.
//

public actor FTPSessionLISTResult {
    
    public enum Result: Sendable {
        case unknown
        case failure
        case success
    }
    
    public let result: Result
    
    public let code: Int?
    public let message: String?
    
    public let files: [FTPFileListItem]?
    
    init(result: Result, code: Int?, message: String?, files: [FTPFileListItem]?) {
        self.result = result
        
        self.code = code
        self.message = message
        
        self.files = files
    }
    
    public func foldersOnly(includingDotFolders: Bool = false) -> [FTPFileListItem]? {
        return files?.compactMap { item in
            (!includingDotFolders && (item.filename == "." || item.filename == "..")) ||
            (item.unixFiletype != .directory)
            ? nil
            : item
        }
    }
    
    public func filesOnly() -> [FTPFileListItem]? {
        return files?.compactMap { item in
            item.unixFiletype == .regular ? item : nil
        }
    }
}
