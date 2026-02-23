//
//  FTPSessionDefinitions.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 11-12-2025.
//

public enum FTPRepresentationType: String {
    case ascii              = "A"           // ASCII
    case ebcdic             = "E"           // EBCDIC
    case image              = "I"           // Image
    case local              = "L"           // Local byte size
}

public enum FTPRepresentationSubtype: String {
    case nonPrint           = "N"           // Non-print
    case telnet             = "T"           // Telnet format effectors
    case carriageControl    = "C"           // Carriage control (ASA)
}

public enum FTPFileStructure: String {
    case file               = "F"           // File (no record structure)
    case record             = "R"           // Record structure
    case page               = "P"           // Page structure
}

public enum FTPTransferMode: String {
    case stream             = "S"           // Stream
    case block              = "B"           // Block
    case compressed         = "C"           // Compressed
}

public enum FTPDataConnectionMode: String {
    case active             = ".active"
    case passive            = ".passive"
    case extendedActive     = ".extendedActive"
    case extendedPassive    = ".extendedPassive"
}

public enum FTPSessionState: Sendable, RawRepresentable {
    
    public typealias RawValue = String
    
    case uninitialised
    case initialised
    case opening
    case opened
    case idle
    case busy
    case closing
    case closed
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
        case ".opening":
            self = .opening
        case ".opened":
            self = .opened
        case ".idle":
            self = .idle
        case ".busy":
            self = .busy
        case ".closing":
            self = .closing
        case ".closed":
            self = .closed
        case ".failed":
            self = .failed(FTPError.unknownError())
        default:
            fatalError("Did you add a new case to FTPSessionState and didn't handle it properly?")
        }
    }
    
    public var rawValue: String {
        switch self {
        case .uninitialised:
            return ".uninitialised"
        case .initialised:
            return ".initialised"
            case .opening:
            return ".opening"
        case .opened:
            return ".opened"
        case .idle:
            return ".idle"
        case .busy:
            return ".busy"
        case .closing:
            return ".closing"
        case .closed:
            return ".closed"
        case .failed(let error):
            return ".failed: \(error)"
        }
    }
}

