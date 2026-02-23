//
//  FTPControlConnection.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 15-10-2025.
//

import Foundation
import Network
import os

actor FTPControlConnection: Sendable {
    
    // MARK: - Internal
    
    internal static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: FTPClientSession.self))
    
    // MARK: - Private
    
    private let session: FTPClientSession?
    
    private let defaultMinimumReceiveSize: Int = 1
    private let defaultMaximumReceiveSize: Int = 1460       // This is what connection?.maximumDatagramSize returns when connected over ethernet.
    
    private let host: NWEndpoint.Host?
    private let port: NWEndpoint.Port?
    
    private let endpoint: NWEndpoint
    private var connection: NWConnection?
    
    private let connectionQueue = DispatchQueue(label: "FTPControlConnectionQueue", attributes: .concurrent)
    
    private var _connectionState: FTPConnectionState = FTPConnectionState.uninitialised
    internal var connectionState: FTPConnectionState {
        get {
            return _connectionState
        }
        set {
            // Only update if the value is really new, we only want to process transitions.
            if _connectionState != newValue {
                Self.logger.trace("connectionState: \(newValue.rawValue)")
                _connectionState = newValue
                // delegate.connectionStateUpdated(connection: self, state: _connectionState)
            }
        }
    }
    
    private var nextFreeUserAddressRangeIPPort: ThreadSafeCounter<UInt16> = ThreadSafeCounter<UInt16>(count: ipv4UserAddressRangeLowerBound,
                                                                                                      lower: ipv4UserAddressRangeLowerBound,
                                                                                                      upper: ipv4UserAddressRangeUpperBound)
    
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
    
    var nextFreeIPPort: FTPIPPort {
        set {
            nextFreeUserAddressRangeIPPort.set(count: newValue.port)
        }
        get {
            let port = FTPIPPort(UInt16(nextFreeUserAddressRangeIPPort.count))
            nextFreeUserAddressRangeIPPort.inc()
            return port
        }
        
    }
        
    // MARK: - Lifecycle
    
    init(session: FTPClientSession) async throws {
        
        let connectionUrl = await session.controlConnectionURL
        
        Self.logger.trace("FTPControlConnection: Initialize with url: \(connectionUrl)")
        
        if let desiredPort = connectionUrl.port, !(0...65535).contains(desiredPort) {
            throw FTPError(.badURL, userinfo: [NSLocalizedDescriptionKey : "FTPControlConnection: Port must be in range of 0-65535, got \(desiredPort)"])
        }
        
        self.session = session
        
        self.host = .init(connectionUrl.host ?? "localhost")
        self.port = .init(integerLiteral: UInt16(connectionUrl.port ?? 21))
        
        guard let host, let port else {
            throw FTPError(.badURL, userinfo: [NSLocalizedDescriptionKey : "FTPControlConnection: Unable to parse URL: \(connectionUrl.absoluteString)"])
        }
        
        self.endpoint = NWEndpoint.hostPort(host: host, port: port)
        
        connectionState = .initialised
    }
    
    deinit {
        
        if _connectionState == .connected, let connection {
            Self.logger.trace("FTPControlConnection: Closing connection on deinit")
            connection.cancel()
        }
        
        Self.logger.trace("FTPControlConnection: Deinitialised")
    }
    
    // MARK: - Public
    
    // MARK: Connection
    
    public func connect(timeout: TimeInterval = FTPClientLibDefaults.timeoutInSecondsForConnection) async throws {
        // NOTE: The 'if case' autoclosure is necessary because we can't normally compare to an enum value with an associated
        // NOTE: value, the compiler will want to see the associated value. Using the 'if case' form, we can actually do it,
        // NOTE: although the syntax is exceedingly ugly.
        guard connectionState == .initialised || connectionState == .disconnected || ({if case .failed = connectionState {true} else {false}}()) else {
            Self.logger.error("FTPControlConnection: Error opening control connection, wrong connection state: \(self.connectionState.rawValue)")
            throw FTPError(.notInitialised, userinfo: [NSLocalizedDescriptionKey : "FTPControlConnection: Not initialised, disconnected or failed"])
        }
        
        Self.logger.trace("FTPControlConnection: Initiating IPv4 connection to server: \(self.endpoint.debugDescription)")
        
        connectionState = .connecting
        
        // NOTE: Force the use of IPv4-only. Implementation is only RFC-959 for now, and it only supports IPv4 addresses.
        // NOTE: IPv6 support is proposed in RFC-2428. We might implement that later.
        let params = NWParameters.tcp
        let ip = params.defaultProtocolStack.internetProtocol! as! NWProtocolIP.Options
        ip.version = .v4
        
        connection = .init(to: endpoint, using: params)
        
        guard let connection else {
            throw FTPError(.unknown, userinfo: [NSLocalizedDescriptionKey : "FTPControlConnection: Failed to create connection object with endpoint \(endpoint.debugDescription)"])
        }
        
        connection.stateUpdateHandler = { state in
            Task {
                await self.connectionStateUpdateHandler(state)
            }
        }
        
        Self.logger.trace("FTPControlConnection: Opening connection")
        
        connection.start(queue: connectionQueue)
        
        Self.logger.trace("FTPControlConnection: Waiting for connection to complete")
        do {
            try await AsyncConditionSpinlock(timeout: timeout, condition: {
                Self.logger.trace("FTPControlConnection: * poll connection state")
                return await self.connectionState != .connecting
            }).waitForCondition()
        }
        catch {
            switch error as? AsyncConditionSpinlock.PollingError {
            case .alreadyRunning:
                fatalError("Poller is already waiting for a condition")
            case .timeout:
                Self.logger.error("FTPControlConnection: Timed out waiting for connection to complete")
                self.connectionState = .failed(FTPError(.connectionFailed, userinfo: [NSLocalizedDescriptionKey : "FTPControlConnection: Connection to server timed out"]))
                connection.forceCancel()
            default:
                Self.logger.error("FTPControlConnection: Unhandled error waiting for connection to complete: \(error)")
                self.connectionState = .failed(FTPError(.connectionFailed, userinfo: [NSLocalizedDescriptionKey : "FTPControlConnection: Unhandled exception while connecting to server: \(error)"]))
            }
        }
        
        guard self.connectionState == .connected else {
            throw FTPError(.connectionFailed, userinfo: [NSLocalizedDescriptionKey : "FTPControlConnection: Connection to server failed (state: \(self.connectionState))"])
        }
        
        Self.logger.info("FTPControlConnection: Connection state is now \(self.connectionState.rawValue)")
    }
    
    public func disconnect() async throws {
        
        if self.connectionState == .disconnected {
            Self.logger.trace("FTPControlConnection: already disconnected while asked to disconnect" )
            return
        }
        else if self.connectionState == .connected {self
            Self.logger.trace("FTPControlConnection: disconnecting gracefully, state: \(self.connectionState.rawValue)" )
            self.connectionState = .disconnecting
            connection?.cancel()
        }
        else {
            Self.logger.trace("FTPControlConnection: disconnecting hard, state: \(self.connectionState.rawValue)" )
            self.connectionState = .disconnected
            connection?.forceCancel()
        }
    }
    
    // MARK: Sending
    
    public func sendCommand(_ command: some FTPCommand) async throws {
        
        Self.logger.info("FTPControlConnection: Sending command: \(command)" )
        
        guard connectionState == .connected, let connection else {
            throw FTPError(.unknown, userinfo: [NSLocalizedDescriptionKey : "FTPControlConnection: No connection"])
        }
        
        guard let commandString = command.commandString, commandString.isEmpty == false else {
            throw FTPError(.commandFailed, userinfo: [NSLocalizedDescriptionKey : "FTPControlConnection: Empty or no commandString"])
        }
        
        var error: NWError? = nil
        
        error = await withCheckedContinuation { continuation in
            connection.send(content: commandString.data(using: .utf8), completion: .contentProcessed({ error in
                continuation.resume(returning: error)
            }))
        }
        
        if let error {
            throw FTPError(.unknown, userinfo: [NSLocalizedDescriptionKey : "FTPControlConnection: Error sending data: \(error)"])
        }
    }
    
    // MARK: Receiving
    
    func receiveReply(commandGroup: FTPCommandGroup) async throws -> FTPCommandResult {
        
        Self.logger.trace("FTPControlConnection: Waiting for reply" )
        
        guard let connection else {
            Self.logger.error("FTPControlConnection: No connection or connection lost before trying to receive reply")
            throw FTPError(.notConnected, userinfo: [NSLocalizedDescriptionKey : "FTPControlConnection: No connection or connection lost before trying to receive reply"])
        }
        
        var receivedCode: Int = 0
        var receivedMessage: String? = nil
        
        var receiveMore: Bool = true
        var lastUnparsedData: Data? = nil
        
        repeat {
            
            let (serverDisconnected, partialData) = try await doReceivePartialReplyData()
            
            var dataToParse: Data = Data()
            
            if let lastUnparsedData {
                dataToParse.append(lastUnparsedData)
            }
            
            if let partialData {
                dataToParse.append(partialData)
            }
            
            do {
                let (replyCode, isComplete, parsedMessage, unparsedData) = try await FTPControlConnectionReplyParser.parseOneLine(dataToParse, commandGroup: commandGroup)
                
                receivedCode = replyCode ?? 0
                
                if let parsedMessage {
                    receivedMessage = (receivedMessage ?? "").appending(parsedMessage)
                }
                
                receiveMore = (serverDisconnected == false) && (isComplete == false)
            }
            catch {
                
            }
        } while receiveMore
        
        return FTPCommandResult(code: receivedCode, message: receivedMessage)
    }
    
    // MARK: - Private
    
    // MARK: Connection
    
    func connectionStateUpdateHandler(_ state: NWConnection.State) async {
        
        Self.logger.trace("FTPControlConnection: Connection state updated to: \(String(describing: state))")
        
        switch state {
        case .setup, .preparing:
            break
        case .ready:
            Self.logger.info("FTPControlConnection: Connected. Local: \(self.localIPAddress?.addressAsString ?? "nil"):\(self.localIPPort?.portAsString ?? "nil"). Remote: \(self.remoteIPAddress?.addressAsString ?? "nil"):\(self.remoteIPPort?.portAsString ?? "nil")")
            if let localIPPort = self.localIPPort?.port {
                self.nextFreeIPPort = FTPIPPort(localIPPort + 1)
                Self.logger.info("FTPControlConnection: Next free user address range IP port is \(self.nextFreeUserAddressRangeIPPort.count)")
            }
            else {
                Self.logger.warning("FTPControlConnection: Connected, but no known local IP port. Setting next free user address range IP port to \(ipv4UserAddressRangeLowerBound).")
                self.nextFreeIPPort = FTPIPPort(ipv4UserAddressRangeLowerBound)
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
                // This is a graceful disconnect. Only update state in this case. In hard disconnect cases, the state
                // will/should already have been set to the desired value.
                self.connectionState = .disconnected
            }
        @unknown default:
            break
        }
    }
    
    // MARK: Receiving
    
    private func doReceivePartialReplyData() async throws -> (disconnected: Bool, partialData: Data?) {
        
        guard let connection else {
            Self.logger.info("FTPControlConnection: Connection lost before trying to receive data")
            return (true, nil)
        }
        
        Self.logger.trace("FTPControlConnection: Initiate a partial receive")
        
        var serverDisconnected: Bool = false
        var receivedData: Data? = nil
        
        (serverDisconnected, receivedData) = await withCheckedContinuation { continuation in
            
            connection.receive(minimumIncompleteLength: defaultMinimumReceiveSize,
                               maximumLength: connection.maximumDatagramSize ?? defaultMaximumReceiveSize,
                               completion: { [weak self] data, context, complete, error in
                
                guard let self else { return }
                
                Self.logger.debug("FTPControlConnection: Received \(data?.count ?? 0) bytes data")
                Self.logger.debug("FTPControlConnection: * context: \(String(describing: context))")
                Self.logger.debug("FTPControlConnection: * complete: \(complete)")
                Self.logger.debug("FTPControlConnection: * error: \(String(describing: error))")
                Self.logger.debug("FTPControlConnection: * Data:")
                Self.logger.debug("FTPControlConnection: ---------------------------")
                Self.logger.debug("FTPControlConnection: \(String(decoding: data ?? Data(), as: Unicode.UTF8.self))")
                Self.logger.debug("FTPControlConnection: ---------------------------")
                
                var disconnected: Bool = false
                
                if complete {
                    // NOTE: We are using TCP, so 'complete' means that the connection was closed.
                    Self.logger.info("FTPControlConnection: Data is complete, disconnected")
                    self.connectionState = .disconnected
                    disconnected = true
                }
                else if error != nil {
                    // NOTE: Not complete, but we did receive an error and cannot continue. Again, most
                    // NOTE: likely the connection was closed, but this time during a transfer of data.
                    Self.logger.error("FTPControlConnection: Error receiving data: \(String(describing: error))")
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
