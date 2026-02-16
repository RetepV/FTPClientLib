//
//  FTPDataConnection.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 03-01-2026.
//

import Foundation
import Network
import os

actor FTPDataConnection: Sendable {
    
    // MARK: - Internal
    
    internal static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: FTPClientSession.self))
    
    // MARK: - Private
    
    private let session: FTPClientSession?
    
    private let defaultMinimumReceiveSize: Int = 1
    private let defaultMaximumReceiveSize: Int = 1460       // This is what connection?.maximumDatagramSize returns when connected over ethernet.
    
    private var endpoint: NWEndpoint? = nil
    private var listener: NWListener? = nil
    private var connection: NWConnection? = nil
    
    private let connectionQueue = DispatchQueue(label: "FTPDataConnectionQueue", attributes: .concurrent)
    private let listenerQueue = DispatchQueue(label: "FTPDataConnectionListenerQueue", attributes: .concurrent)

    private var _connectionState: FTPConnectionState = FTPConnectionState.uninitialised
    internal var connectionState: FTPConnectionState {
        get {
            return _connectionState
        }
        set {
            if _connectionState != newValue {
                Self.logger.trace("FTPDataConnection: connectionState: \(newValue.rawValue)")
                _connectionState = newValue
            }
        }
    }
    
    private var isReceiving: Bool = false
    private var receivedData: Data = Data()
    
    // MARK: - Public
    
    var remoteIPAddress: FTPIPAddress? {
        if let hostport = connection?.currentPath?.remoteEndpoint {
            switch hostport {
            case .hostPort(host: let host, port: let port):
                switch host {
                case .ipv4(let address):
                    return FTPIPAddress(address.rawValue)
                default:
                    assertionFailure("We only support IPv4 right now, make sure to force Network to use IPv4")
                    break
                }
            default:
                break
            }
        }
        return nil
    }
    
    var remoteIPPort: FTPIPPort? {
        if let hostport = connection?.currentPath?.remoteEndpoint {
            switch hostport {
            case .hostPort(host: let host, port: let port):
                switch host {
                case .ipv4:
                    return FTPIPPort(port.rawValue)
                default:
                    break
                }
            default:
                break
            }
        }
        return nil
    }
    
    var localIPAddress: FTPIPAddress? {
        if let hostport = connection?.currentPath?.localEndpoint {
            switch hostport {
            case .hostPort(host: let host, port: let port):
                switch host {
                case .ipv4(let address):
                    return FTPIPAddress(address.rawValue)
                default:
                    assertionFailure("We only support IPv4 right now, make sure to force Network to use IPv4")
                    break
                }
            default:
                break
            }
        }
        return nil
    }
    
    var localIPPort: FTPIPPort? {
        if let hostport = connection?.currentPath?.localEndpoint {
            switch hostport {
            case .hostPort(host: let host, port: let port):
                switch host {
                case .ipv4:
                    return FTPIPPort(port.rawValue)
                default:
                    break
                }
            default:
                break
            }
        }
        return nil
    }
    
    var nextFreeUserAddressRangeIPPort: ThreadSafeCounter<UInt16> = ThreadSafeCounter<UInt16>(count: ipv4UserAddressRangeLowerBound,
                                                                                              lower: ipv4UserAddressRangeLowerBound,
                                                                                              upper: ipv4UserAddressRangeUpperBound)
    
    // MARK: - Lifecycle
    
    init(session: FTPClientSession) async throws {
        
        Self.logger.trace("FTPDataConnection: Initialize")
        
        self.session = session
                
        connectionState = .initialised
    }
    
    deinit {
        
        if _connectionState == .connected, let connection {
            Self.logger.trace("FTPDataConnection: Closing connection on deinit")
            connection.cancel()
        }
    }
    
    // MARK: - Public
    
    // MARK: Connection
    
    public func connect(address: FTPIPAddress, port: FTPIPPort, timeout: TimeInterval = FTPClientLibDefaults.timeoutInSecondsForConnection) async throws {

        guard connectionState == .initialised || connectionState == .disconnected || ({if case .failed = connectionState {true} else {false}}()) else {
            Self.logger.error("FTPDataConnection: Error opening data connection, wrong connection state: \(self.connectionState.rawValue)")
            throw FTPError(.notInitialised, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: Not initialised, disconnected or failed"])
        }
        
        guard let addressString = address.addressAsString,
              let endpointPort = NWEndpoint.Port(rawValue: port.port) else {
            Self.logger.error("FTPDataConnection: Error endpoint for address \(address.addressAsString ?? "nil") and port \(port.port)")
            throw FTPError(.notInitialised, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: Invalid address or port"])
        }
        
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(addressString),
                                           port: endpointPort)
        self.endpoint = endpoint
        
        Self.logger.info("FTPDataConnection: Initiating IPv4 connection to server: \(self.endpoint.debugDescription)")
        
        connectionState = .connecting
        
        // NOTE: Force the use of IPv4-only. Implementation is only RFC-959 for now, and it only supports IPv4 addresses.
        // NOTE: IPv6 support is proposed in RFC-2428. We might implement that later.
        let params = NWParameters.tcp
        let ip = params.defaultProtocolStack.internetProtocol! as! NWProtocolIP.Options
        ip.version = .v4
        
        connection = .init(to: endpoint, using: params)
        
        guard let connection else {
            throw FTPError(.unknown, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: Failed to create connection object with endpoint \(endpoint.debugDescription)"])
        }
        
        connection.stateUpdateHandler = { state in
            Task {
                await self.connectionStateUpdateHandler(state)
            }
        }
        
        Self.logger.trace("FTPDataConnection: Opening connection")
        
        connection.start(queue: connectionQueue)
        
        Self.logger.trace("FTPDataConnection: Waiting for connection to complete")
        do {
            try await AsyncConditionSpinlock(timeout: timeout, condition: {
                Self.logger.trace("FTPDataConnection: * Poll connection state")
                return await self.connectionState != .connecting
            }).waitForCondition()
        }
        catch {
            switch error as? AsyncConditionSpinlock.PollingError {
            case .alreadyRunning:
                fatalError("Poller is already waiting for a condition")
            case .timeout:
                Self.logger.error("FTPDataConnection: Timed out waiting for connection to complete")
                self.connectionState = .failed(FTPError(.connectionFailed, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: Connection to server timed out"]))
                connection.forceCancel()
            default:
                Self.logger.error("FTPDataConnection: Unhandled error waiting for connection to complete: \(error)")
                self.connectionState = .failed(FTPError(.connectionFailed, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: Unhandled exception while connecting to server: \(error)"]))
            }
        }
        
        Self.logger.trace("FTPDataConnection: Connection state is now \(self.connectionState.rawValue)")
        
        guard self.connectionState == .connected else {
            throw FTPError(.connectionFailed, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: Connection to server failed (state: \(self.connectionState))"])
        }
    }
    
    public func listen(port: FTPIPPort) async throws {
        
        guard connectionState == .initialised || connectionState == .disconnected || ({if case .failed = connectionState {true} else {false}}()) else {
            Self.logger.error("FTPDataConnection: Error listening for data connection, wrong connection state: \(self.connectionState.rawValue)")
            throw FTPError(.notInitialised, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: Not initialised, disconnected or failed"])
        }
        
        Self.logger.trace("FTPDataConnection: Listen for a connection")
        
        connectionState = .startListening
        
        // NOTE: Force the use of IPv4-only. Implementation is only RFC-959 for now, and it only supports IPv4 addresses.
        // NOTE: IPv6 support is proposed in RFC-2428. We might implement that later.
        let params = NWParameters.tcp
        let ip = params.defaultProtocolStack.internetProtocol! as! NWProtocolIP.Options
        ip.version = .v4
        
        guard let networkPort = NWEndpoint.Port(rawValue: port.port) else {
            throw FTPError(.notInitialised, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: Could not create endpoint with port \(port)"])
        }
        
        listener = try .init(using: params, on: networkPort)
        
        guard let listener else {
            throw FTPError(.unknown, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: Failed to create listener object with port \(port.portAsString)"])
        }
        
        listener.stateUpdateHandler = { state in
            Task {
                await self.listenerStateUpdateHandler(state)
            }
        }
        
        listener.newConnectionHandler = { newConnection in
            Task {
                await self.acceptConnection(newConnection)
            }
        }

        Self.logger.trace("FTPDataConnection: Start listening")
        
        listener.start(queue: listenerQueue)
    }
    
    public func waitForConnection(timeout: TimeInterval = FTPClientLibDefaults.timeoutInSecondsForConnection) async throws {
        
        guard connectionState == .listening else {
            Self.logger.error("FTPDataConnection: Error waiting for connection, wrong connection state: \(self.connectionState.rawValue)")
            throw FTPError(.notInitialised, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: Not listening"])
        }
        
        do {
            try await AsyncConditionSpinlock(timeout: timeout, condition: {
                Self.logger.trace("FTPDataConnection: * Poll connection state")
                let state = await self.connectionState
                // Poll until state is no longer 'listening', nor 'connecting. We should then either
                // be connected, timed out or in an error state.
                return (state != .listening) && (state != .connecting)
            }).waitForCondition()
        }
        catch {
            switch error as? AsyncConditionSpinlock.PollingError {
            case .alreadyRunning:
                fatalError("Poller is already waiting for a condition")
            case .timeout:
                Self.logger.error("FTPDataConnection: Timed out waiting for data connection to complete")
                self.connectionState = .failed(FTPError(.connectionFailed, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: Waiting for connection timed out"]))
                connection?.forceCancel()
            default:
                Self.logger.error("FTPDataConnection: Unhandled error waiting for data connection to complete: \(error)")
                self.connectionState = .failed(FTPError(.connectionFailed, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: Unhandled exception while connecting to server: \(error)"]))
            }
        }
        
        Self.logger.trace("FTPDataConnection: Connection state is now \(self.connectionState.rawValue)")
        
        guard self.connectionState == .connected else {
            throw FTPError(.connectionFailed, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: Connection to server failed (state: \(self.connectionState))"])
        }
    }
    
    public func disconnect() async throws {
        
        if self.connectionState == .disconnected {
            Self.logger.trace("FTPDataConnection: already disconnected while asked to disconnect" )
            return
        }
        else if self.connectionState == .connected {self
            Self.logger.trace("FTPDataConnection: disconnecting gracefully, state: \(self.connectionState.rawValue)" )
            self.connectionState = .disconnecting
            connection?.cancel()
        }
        else {
            Self.logger.trace("FTPDataConnection: disconnecting hard, state: \(self.connectionState.rawValue)" )
            self.connectionState = .disconnected
            connection?.forceCancel()
        }
    }
    
    // MARK: Sending
    
    public func send(_ data: Data) async throws {
        
        Self.logger.trace("FTPDataConnection: Sending \(data.count) bytes of data" )
        
        guard connectionState == .connected, let connection else {
            throw FTPError(.unknown, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: No connection"])
        }
        
        var error: NWError? = nil
        
        error = await withCheckedContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed({ error in
                continuation.resume(returning: error)
            }))
        }
        
        connection.cancel()
        
        if let error {
            throw FTPError(.unknown, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: Error sending data: \(error)"])
        }
        
        Self.logger.trace("FTPDataConnection: Finished sending \(data.count) bytes of data" )
    }
    
    public func send(_ fileURL: URL) async throws {
        
        Self.logger.trace("FTPDataConnection: Sending file: \(fileURL.path)" )
        
        guard connectionState == .connected, let connection else {
            throw FTPError(.unknown, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: No connection"])
        }
        
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: fileURL.path) {
            throw FTPError(.fileOpenFailed, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: File doesn't exist: \(fileURL.path)"])
        }
        
        var fileHandle: FileHandle?
        
        do {
            fileHandle = try FileHandle(forReadingAtPath: fileURL.path)
        }
        catch {
            throw FTPError(.fileOpenFailed, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: File could not be opened: \(fileURL.path), error: \(error)"])
        }
        
        guard let fileHandle else {
            throw FTPError(.fileOpenFailed, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: Unexpectedly found nil for fileHandle after opening file"])
        }

        defer {
            fileHandle.closeFile()
        }
        
        var numberOfBytesSent: Int = 0
        var sendMore: Bool = true
        var data: Data?
        var error: NWError? = nil

        repeat {
            do {
                data = try await fileHandle.read(upToCount: defaultMaximumReceiveSize)
            }
            catch {
                throw FTPError(.fileReadFailed, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: Unable to read from file handle, error: \(error)"])
            }
            
            Self.logger.trace("FTPDataConnection: connection: \(connection.debugDescription)")

            error = await withCheckedContinuation { continuation in
                Self.logger.trace("FTPDataConnection: Sending \(data?.count ?? 0) bytes of data" )
                connection.send(content: data, completion: .contentProcessed({ error in
                    let dataCount = data?.count ?? 0
                    Self.logger.trace("FTPDataConnection: Sent \(dataCount) bytes, error: \(String(describing: error))" )
                    continuation.resume(returning: error)
                }))
            }
            
            numberOfBytesSent += data?.count ?? 0
            
            sendMore = (data?.count ?? 0 == defaultMaximumReceiveSize) || (error != nil)
            
            Self.logger.trace("FTPDataConnection: numberOfBytesSent: \(numberOfBytesSent), sendMore \(sendMore)" )

        } while sendMore
        
        connection.cancel()
        
        if let error {
            throw FTPError(.unknown, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: Error sending data: \(error)"])
        }
        
        Self.logger.trace("FTPDataConnection: Finished sending \(numberOfBytesSent) bytes of data" )
    }

    
    // MARK: Receiving

    func receiveInMemory() async throws -> FTPDataResult? {
        
        Self.logger.trace("FTPDataConnection: Receiving data to memory until sender closes connection." )
        
        guard let connection else {
            Self.logger.error("FTPDataConnection: No connection or connection lost before trying to receive reply")
            throw FTPError(.notConnected, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: No connection or connection lost before trying to receive reply"])
        }
        
        var numberOfBytesReceived: Int = 0
        var receivedData: Data?
        var receiveMore: Bool = true
        
        repeat {
            
            let (serverDisconnected, partialData) = try await doReceivePartialReplyData()
            
            if let partialData {
                
                if receivedData == nil {
                    receivedData = Data()
                }
                
                numberOfBytesReceived += partialData.count
                receivedData?.append(partialData)
            }
            
            receiveMore = !serverDisconnected
            
        } while receiveMore
        
        return FTPDataResult(size: numberOfBytesReceived, data: receivedData)
    }

    func receiveToFile(fileURL: URL, writeMode: FTPFileWriteMode = .safeWithRename) async throws -> FTPDataResult? {
        
        Self.logger.trace("FTPDataConnection: Receiving data to file until sender closes connection." )
        
        guard let connection else {
            Self.logger.error("FTPDataConnection: No connection or connection lost before trying to receive reply")
            throw FTPError(.notConnected, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: No connection or connection lost before trying to receive reply"])
        }
        
        let fileManager = FileManager.default
        var actualFileURL = fileURL
        
        if fileManager.fileExists(atPath: actualFileURL.path) {
            switch writeMode {
            case .safe:
                Self.logger.error("FTPDataConnection: File exists and cannot be overwritten: \(actualFileURL.path)")
                throw FTPError(.notConnected, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: File exists and cannot be overwritten: \(actualFileURL.path)"])
            case .safeWithRename:
                Self.logger.error("FTPDataConnection: File exists, change name to unique name: \(actualFileURL.path)")
                actualFileURL = FileUtilities.makeUniqueNumberedFile(actualFileURL)
            case .overwrite, .append:
                break
            }
        }
        
        var fileHandle: FileHandle? = nil
        
        do {
            switch writeMode {
            case .safe, .safeWithRename, .overwrite:
                fileManager.createFile(atPath: actualFileURL.path, contents: nil)
                fileHandle = try FileHandle(forWritingTo: actualFileURL)
                Self.logger.info("FTPDataConnection: Opened file for writing: \(actualFileURL.path)")
            case .append:
                fileHandle = try FileHandle(forUpdating: actualFileURL)
                try fileHandle?.seekToEnd()
                Self.logger.info("FTPDataConnection: Opened file for appending: \(actualFileURL.path)")
            }
        }
        catch {
            throw FTPError(.fileOpenFailed, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: Could not open file: \(actualFileURL), error: \(error)"])
        }
        
        guard let fileHandle else {
            throw FTPError(.fileOpenFailed, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: Unexpectedly found nil for fileHandle after opening file"])
        }

        defer {
            fileHandle.closeFile()
        }
        
        var numberOfBytesReceived: Int = 0
        var receiveMore: Bool = true
        
        repeat {
            
            let (serverDisconnected, partialData) = try await doReceivePartialReplyData()
            
            if let partialData {
                
                do {
                    try fileHandle.write(contentsOf: partialData)
                }
                catch {
                    throw FTPError(.fileWriteFailed, userinfo: [NSLocalizedDescriptionKey : "FTPDataConnection: Unexpectedly unable to write to file: \(actualFileURL), error: \(error)"])
                }
                
                numberOfBytesReceived += partialData.count
            }
            
            receiveMore = !serverDisconnected
            
        } while receiveMore
        
        return FTPDataResult(size: numberOfBytesReceived, fileURL: actualFileURL)
    }

    // MARK: - Private
    
    // MARK: Connection
    
    func connectionStateUpdateHandler(_ state: NWConnection.State) async {
        
        Self.logger.trace("FTPDataConnection: Connection state updated to: \(String(describing: state))")
        
        switch state {
        case .setup, .preparing:
            break
        case .ready:
            Self.logger.info("FTPDataConnection: Connected, local: \(self.localIPAddress?.addressAsString ?? "nil"):\(self.localIPPort?.portAsString ?? "nil"), remote: \(self.remoteIPAddress?.addressAsString ?? "nil"):\(self.remoteIPPort?.portAsString ?? "nil")")
            if let localIPPort = self.localIPPort?.port {
                self.nextFreeUserAddressRangeIPPort.set(count: localIPPort)
                self.nextFreeUserAddressRangeIPPort.inc()
                Self.logger.info("FTPDataConnection: Next free user address range IP port is \(self.nextFreeUserAddressRangeIPPort.count)")
            }
            else {
                Self.logger.warning("FTPDataConnection: Connected, but no known local IP port. Setting next free user address range IP port to 41952.")
                self.nextFreeUserAddressRangeIPPort.set(count: ipv4UserAddressRangeLowerBound)
            }
            self.connectionState = .connected
        case .waiting(let error):
            // NOTE: Is there a case that we might receive '.waiting' in a non-error situation? Handle
            // NOTE: all cases as errors for now.
            self.connectionState = .failed(error)
        case .failed(let error):
            self.connectionState = .failed(error)
        case .cancelled:
            if self.connectionState == .disconnecting {
                // This is a graceful disconnect. Only update the state in this case. In 'hard' disconnect
                // cases, the state will/should already have been set to the desired value.
                self.connectionState = .disconnected
            }
        @unknown default:
            break
        }
    }

    func listenerStateUpdateHandler(_ state: NWListener.State) async {
        
        Self.logger.trace("FTPDataConnection: Listener state updated to: \(String(describing: state))")
        
        switch state {
        case .setup:
            break
        case .waiting(let error):
            break
        case .ready:
            self.connectionState = .listening
        case .failed(let error):
            self.connectionState = .failed(error)
        case .cancelled:
            if self.connectionState == .disconnecting {
                // This is a graceful disconnect. Only update state in this case. In hard disconnect cases, the state
                // will/should already have been set to the desired value.
                self.connectionState = .disconnected
            }
        @unknown default:
            break
        }
    }
    
    func acceptConnection(_ connection: NWConnection) async {
        
        Self.logger.trace("FTPDataConnection: Accept a new connection: \(connection.debugDescription)")
        
        self.connection = connection
        
        self.connection?.stateUpdateHandler = { state in
           Task {
               await self.connectionStateUpdateHandler(state)
           }
       }
        
        self.connection?.start(queue: connectionQueue)
        
        //self.connectionState = .connected
    }

    // MARK: Receiving
    
    private func doReceivePartialReplyData() async throws -> (disconnected: Bool, partialData: Data?) {
        
        guard let connection else {
            Self.logger.info("FTPDataConnection: Connection lost before trying to receive data")
            return (true, nil)
        }
        
        Self.logger.trace("FTPDataConnection: Initiate a partial receive")
        
        var serverDisconnected: Bool = false
        var receivedData: Data? = nil
        
        (serverDisconnected, receivedData) = await withCheckedContinuation { continuation in
            
            connection.receive(minimumIncompleteLength: defaultMaximumReceiveSize, // defaultMinimumReceiveSize,
                               maximumLength: connection.maximumDatagramSize ?? defaultMaximumReceiveSize,
                               completion: { [weak self] data, context, complete, error in
                
                guard let self else { return }
                
                Self.logger.debug("FTPDataConnection:  Received \(data?.count ?? 0) bytes data")
                Self.logger.debug("FTPDataConnection:  * context: \(String(describing: context))")
                Self.logger.debug("FTPDataConnection:  * complete: \(complete)")
                Self.logger.debug("FTPDataConnection:  * error: \(String(describing: error))")
                Self.logger.debug("FTPDataConnection:  * Data:")
                Self.logger.debug("FTPDataConnection:  ---------------------------")
                Self.logger.debug("FTPDataConnection:  \(String(decoding: data ?? Data(), as: Unicode.UTF8.self))")
                Self.logger.debug("FTPDataConnection:  ---------------------------")
                
                var disconnected: Bool = false
                
                if complete {
                    // NOTE: We are using TCP, so 'complete' means that the connection was closed.
                    Self.logger.trace("FTPDataConnection: Data is complete, disconnected")
                    self.connectionState = .disconnected
                    disconnected = true
                }
                else if error != nil {
                    // NOTE: Not complete, but we did receive an error and cannot continue. Again, most
                    // NOTE: likely the connection was closed, but this time during a transfer of data.
                    Self.logger.error("FTPDataConnection: Error receiving data: \(String(describing: error))")
                    self.connectionState = .failed(FTPError(.connectionFailed, userinfo: [NSLocalizedDescriptionKey : "FTPControlConnection: Error receiving data: \(error)"]))
                    self.connectionState = .disconnected
                    disconnected = true
                }
                
                continuation.resume(returning: (disconnected, data))
            })
        }
        
        return (serverDisconnected, receivedData)
    }
}
