//
//  FTPGeneralDefinitions.swift
//  FTPClient
//
//  Created by Peter de Vroomen on 09-02-2025.
//

import Foundation
import Network

public struct FTPClientLibDefaults {
    static public let timeoutInSecondsForConnection: TimeInterval = 15.0
    static public let timeoutInSecondsForListen: TimeInterval = 2.0 * 60.0
    static public let timeoutInSecondsForCommandExecution: TimeInterval = 5.0 * 60.0
}

let ipv4UserAddressRangeLowerBound: UInt16 = 49152
let ipv4UserAddressRangeUpperBound: UInt16 = 65535

public struct FTPIPAddress: Equatable, Sendable {
    
    private let h1: UInt8
    private let h2: UInt8
    private let h3: UInt8
    private let h4: UInt8
    
    // MARK: - Accessors
    
    var isUnspecified: Bool {
        return h1 == 0 && h2 == 0 && h3 == 0 && h4 == 0
    }

    var isLocalhost: Bool {
        return h1 == 127 && h2 == 0 && h3 == 0 && h4 == 1
    }

    var addressAsOctets: [UInt8]? {
        return isUnspecified ? nil : [h1, h2, h3, h4]
    }
    
    var addressAsTuple: (UInt8, UInt8, UInt8, UInt8)? {
        return isUnspecified ? nil : (h1, h2, h3, h4)
    }
    
    var addressAsString: String? {
        return isUnspecified ? nil : "\(h1).\(h2).\(h3).\(h4)"
    }
    
    var addressAsCommaSeparatedString: String? {
        return isUnspecified ? nil : "\(h1),\(h2),\(h3),\(h4)"
    }
    
    var addressAsData: Data? {
        return isUnspecified ? nil : Data([h1, h2, h3, h4])
    }
    
    var addressAsIPv4Address: IPv4Address? {
        if !isUnspecified, let addressAsString {
            return IPv4Address(addressAsString)
        }
        return nil
    }
    
    // MARK: - Lifecycle
    
    init(_ addres: FTPIPAddress) {
        self.h1 = addres.h1
        self.h2 = addres.h2
        self.h3 = addres.h3
        self.h4 = addres.h4
    }
    
    init(_ octets: [UInt8]) {
        assert(octets.count == 4)
        
        self.h1 = octets[0]
        self.h2 = octets[1]
        self.h3 = octets[2]
        self.h4 = octets[3]
    }
    
    init(_ tuple: (h1: UInt8, h2: UInt8, h3: UInt8, h4: UInt8)) {
        self.h1 = tuple.h1
        self.h2 = tuple.h2
        self.h3 = tuple.h3
        self.h4 = tuple.h4
    }
    
    init(_ string: String) {
        let octets: [UInt8] = string.split(separator: ".").compactMap { UInt8($0) }
        
        assert(octets.count == 4)
        
        self.h1 = octets[0]
        self.h2 = octets[1]
        self.h3 = octets[2]
        self.h4 = octets[3]
    }
    
    init(_ data: Data) {
        h1 = data[0]
        h2 = data[1]
        h3 = data[2]
        h4 = data[3]
    }
    
    init(_ ipv4Address: IPv4Address) {
        let data = ipv4Address.rawValue

        h1 = data[0]
        h2 = data[1]
        h3 = data[2]
        h4 = data[3]
    }
    
    init(_ h1: UInt8, _ h2: UInt8, _ h3: UInt8, _ h4: UInt8) {
        self.h1 = h1
        self.h2 = h2
        self.h3 = h3
        self.h4 = h4
    }
    
    // MARK: - Helper functions
    
    static func localhost() -> FTPIPAddress {
        return FTPIPAddress(127, 0, 0, 1)
    }
    
    static func unspecified() -> FTPIPAddress {
        return FTPIPAddress(0, 0, 0, 0)
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: FTPIPAddress, rhs: FTPIPAddress) -> Bool {
        return (lhs.h1 == rhs.h1 &&
                lhs.h2 == rhs.h2 &&
                lhs.h3 == rhs.h3 &&
                lhs.h4 == rhs.h4)
    }
}

public struct FTPIPPort: Equatable, Sendable {
    
    private let p1: UInt8
    private let p2: UInt8
    
    // MARK: - Accessors
    
    var isUnspecified: Bool {
        return p1 == 0 && p2 == 0
    }

    var portAsOctets: [UInt8] {
        return [p1, p2]
    }
    
    var portAsTuple: (UInt8, UInt8) {
        return (p1, p2)
    }
    
    var portAsTupleString: String {
        return "\(p1).\(p2)"
    }
    
    var portAsCommaSeparatedTupleString: String? {
        return isUnspecified ? nil : "\(p1),\(p2)"
    }
    
    var portAsString: String {
        return "\(port)"
    }

    var port: UInt16 {
        return (UInt16(p1) << 8) | UInt16(p2)
    }
    
    // MARK: - Utility
    
    // Always returns a port in the free range of IP ports [49152,65535].
    func incremented(by: UInt16) -> FTPIPPort {
        var incrementedPort = UInt32(self.port) + UInt32(by)
        if incrementedPort > 65535 {
            incrementedPort = 49152 + (incrementedPort - 65535)
        }
        return FTPIPPort(UInt16(incrementedPort))
    }
    
    // Always returns a port in the free range of IP ports [49152,65535]
    func decremented(by: UInt16) -> FTPIPPort {
        var incrementedPort = UInt32(self.port) - UInt32(by)
        if incrementedPort < 49152 {
            incrementedPort = 65535 - (49152 - incrementedPort)
        }
        return FTPIPPort(UInt16(incrementedPort))
    }
    
    // MARK: - Lifecycle
    
    init(_ p1: UInt8, _ p2: UInt8) {
        self.p1 = p1
        self.p2 = p2
    }
    
    init(_ port: UInt16) {
        self.p1 = UInt8(port >> 8)
        self.p2 = UInt8(port & 0xFF)
    }
    
    init(_ port: FTPIPPort) {
        self.p1 = port.p1
        self.p2 = port.p2
    }
    
    public static func == (lhs: FTPIPPort, rhs: FTPIPPort) -> Bool {
        return (lhs.p1 == rhs.p1 &&
                lhs.p2 == rhs.p2)
    }
    
    // MARK: HElper functions
    
    static func unspecified() -> FTPIPPort {
        return FTPIPPort(0, 0)
    }
}
