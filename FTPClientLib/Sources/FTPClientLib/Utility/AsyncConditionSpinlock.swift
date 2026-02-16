//
//  AsyncConditionSpinlock.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 16-12-2025.
//

import Foundation

final actor AsyncConditionSpinlock {
    
    // MARK: - Definitions
    
    enum PollingError: Error {
        case none
        case timeout
        case alreadyRunning
    }
            
    private let interval: TimeInterval
    private let timeout: TimeInterval
    private let condition: () async throws -> Bool

    private var isRunning: Bool = false

    private var startTime: TimeInterval?
    
    init(interval: TimeInterval = 0.1, timeout: TimeInterval = 30, condition: @escaping @Sendable () async throws -> Bool) {
        self.interval = interval
        self.timeout = timeout
        self.condition = condition
    }
    
    func waitForCondition() async throws {

        guard !isRunning else {
            throw PollingError.alreadyRunning
        }

        isRunning = true
        defer {
            isRunning = false
            startTime = 0
        }
        
        startTime = Date.now.timeIntervalSince1970

        while !Task.isCancelled {
            
            if try await condition() {
                return
            }
            
            try await Task.sleep(nanoseconds: UInt64(interval * Double(NSEC_PER_SEC)))
            
            if let startTime, (Date.now.timeIntervalSince1970 - startTime) > timeout {
                throw PollingError.timeout
            }
        }
    }
}
