//
//  FTPClientLib.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 11-12-2025.
//

import Foundation
import Network

public class FTPClientLib {
    
    // MARK: Public
    
    public static func createSession(url: URL) -> FTPClientSession {
        return FTPClientSession(url: url)
    }
}
