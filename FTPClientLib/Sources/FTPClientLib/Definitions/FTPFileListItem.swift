//
//  File.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 05-01-2026.
//

import Foundation

public struct FTPFileListItem : Sendable {
    
    public let rawItem: String
    
    public let filename: String
    
    public let unixFiletype: FTPUnixFileType
    
    public let unixUserModeBits: [FTPUnixFileModeBits]
    public let unixGroupModeBits: [FTPUnixFileModeBits]
    public let unixOtherModeBits: [FTPUnixFileModeBits]
    
    public let sizeInBytes: UInt64
    
    public let dateModified: Date

    public let user: String
    public let group: String
}
