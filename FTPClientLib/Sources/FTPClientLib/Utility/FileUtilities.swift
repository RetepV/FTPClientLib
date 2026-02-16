//
//  FileUtilities.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 09-01-2026.
//

import Foundation

public class FileUtilities {
    
    static func makeUniqueNumberedFile(_ fileURL: URL) -> URL {
        let fileManager = FileManager.default

        let filePath: String = fileURL.deletingLastPathComponent().path
        let fileName: String = fileURL.deletingPathExtension().lastPathComponent
        let fileExtension: String = fileURL.pathExtension
        
        var fileNumber: Int = 0
        
        var actualFilePath: String = "\(filePath)/\(fileName).\(fileExtension)"
        
        while fileManager.fileExists(atPath: actualFilePath) {
            actualFilePath = "\(filePath)/\(fileName) \(fileNumber).\(fileExtension)"
            fileNumber += 1
        }
        
        return URL(fileURLWithPath: actualFilePath)
    }
}
