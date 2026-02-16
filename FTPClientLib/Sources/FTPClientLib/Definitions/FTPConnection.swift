//
//  FTPConnection.swift
//  FTPClient
//
//  Created by Peter de Vroomen on 09-02-2025.
//

import Foundation

public enum FTPFileWriteMode: Sendable {
    case safe               // If the file exists, do not overwrite it but throw an error.
    case safeWithRename     // If the file exists, add a number to the filename until a unique name is found.
    case overwrite          // Overwrite file if it exists, create new file if it doesn't exist.
    case append             // Append to a file if it exists, create new file if it doesn't exist.
}

public enum FTPConnectionState: Sendable, RawRepresentable {

    public typealias RawValue = String
    
    case uninitialised
    case initialised
    case startListening
    case listening
    case connecting
    case connected
    case disconnecting
    case disconnected
    case failed(Error)

    // You should really not initialise from a String, this is only added for
    // conformance to RawRepresentable. We really only want to have descriptive
    // descriptions while also having associated values. We want to have the
    // cake and eat it too.
    public init?(rawValue: String) {
        switch rawValue {
        case ".uninitialised":
            self = .uninitialised
        case ".initialised":
            self = .initialised
        case ".startListening":
            self = .startListening
        case ".listening":
            self = .listening
        case ".connecting":
            self = .connecting
        case ".connected":
            self = .connected
        case ".disconnecting":
            self = .disconnecting
        case ".disconnected":
            self = .disconnected
        case ".failed":
            self = .failed(FTPError.unknownError())
        default:
            fatalError("Did you add a new case to FTPConnectionState and didn't handle it properly?")
        }
    }
    
    public var rawValue: String {
        switch self {
        case .uninitialised:
            return ".uninitialised"
        case .initialised:
            return ".initialised"
        case .startListening:
            return ".startListening"
        case .listening:
            return ".listening"
        case .connecting:
            return ".connecting"
        case .connected:
            return ".connected"
        case .disconnecting:
            return ".disconnecting"
        case .disconnected:
            return ".disconnected"
        case .failed(let error):
            return ".failed: \(error)"
        }
    }
}

