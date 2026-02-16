//
//  ContentView.swift
//  FTPClient
//
//  Created by Peter de Vroomen on 15-10-2025.
//

import SwiftUI
import SwiftData

import FTPClientLib
internal import UniformTypeIdentifiers

let defaultServerName = "demo.wftpserver.com"
let defaultServerPort = "21"
let defaultUsername = "demo"
let defaultPassword = "demo"

struct ContentView: View {
    
    @State private var ftpClientSession: FTPClientSession? = nil

    @State private var showConnectionOpening: Bool = false
    @State private var showConnectionOpened: Bool = false
    @State private var showConnectionClosing: Bool = false
    @State private var showConnectionError: Bool = false
    @State private var showAskForDirectory: Bool = false
    @State private var showAskForUploadFile: Bool = false
    
    @State private var directories: [String] = []
    @State private var directoryToChangeTo: String = ""

    @State private var hasOpenConnection: Bool = false
    
    @State private var openResult: FTPSessionOpenResult? = nil
    
    @State private var connectionError: FTPError? = nil
    
    @State private var serverName: String = ""
    @State private var serverPort: String = ""

    @State private var filePath: String = ""

    @State private var logLines: [String] = []
    
    @State private var dataConnectionModes: [(String, FTPDataConnectionMode)] = [("Active", .active), ("Passive", .passive)]
    @State private var dataConnectionMode: FTPDataConnectionMode = .active

    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    private var fullServerURL: URL? {
        let server = serverName.isEmpty ? defaultServerName : serverName
        let port = serverPort.isEmpty ? defaultServerPort : serverPort
        guard server.isEmpty == false, port.isEmpty == false else {
            return nil
        }
        return URL(string: "ftp://\(server):\(port)")
    }

    var body: some View {
        VStack {
            
            HStack {
                VStack(alignment: .leading) {
                    HStack(alignment: .center) {
                        Text("Server:")
                            .frame(width: 60, alignment: Alignment.leading)
                        TextField(text: $serverName) {
                            Text(defaultServerName)
                        }
                        .padding(.horizontal, 4)
                        .background(.gray.opacity(0.2))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.black, lineWidth: 1)
                        )
                    }
                    
                    HStack(alignment: .center) {
                        Text("Port:")
                            .frame(width: 60, alignment: Alignment.leading)

                        HStack() {
                            
                            TextField("", text: $serverPort, prompt: Text(defaultServerPort))
                                .frame(width: 50)
                                .padding(.horizontal, 4)
                                .background(.gray.opacity(0.2))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(.black, lineWidth: 1)
                                )
                            
                            HStack {
                                Spacer()
                                
                                Button {
                                    if let fullServerURL {
                                        createAndOpenFTPSession(url: fullServerURL, dataConnectionMode: dataConnectionMode)
                                    }
                                } label: {
                                    BorderedButtonView(button: (backgroundColor: .yellow, borderColor: .black),
                                                       label: (label: "Connect", labelColor: .black),
                                                       badge: nil,
                                                       disabled: fullServerURL == nil || hasOpenConnection,
                                                       emphasized: false)
                                }
                                
                                Button {
                                    Task {
                                        if let ftpClientSession, await ftpClientSession.sessionState == .opened {
                                            closeFTPSession()
                                        }
                                    }
                                } label: {
                                    BorderedButtonView(button: (backgroundColor: .yellow, borderColor: .black),
                                                       label: (label: "Disconnect", labelColor: .black),
                                                       badge: nil,
                                                       disabled: !hasOpenConnection,
                                                       emphasized: false)
                                }
                            }
                        }
                    }
                    
                    HStack(alignment: .center) {
                        Text("Connection mode: ")
                        
                        Spacer()
                        
                        BorderedSegmentedPickerView<FTPDataConnectionMode>(labels: dataConnectionModes,
                                                                           selected: $dataConnectionMode,
                                                                           labelColor: .black,
                                                                           segment: (.yellow, .black),
                                                                           disabled: hasOpenConnection)
                    }
                }
            }
            .padding(.horizontal)

            Divider()
            
            HStack {
                
                Button {
                    login(username: defaultUsername, password: defaultPassword)
                } label: {
                    BorderedButtonView(button: (backgroundColor: .yellow, borderColor: .black),
                                       label: (label: "Login", labelColor: .black),
                                       badge: nil,
                                       disabled: !hasOpenConnection,
                                       emphasized: false)
                }
                
                Button {
                    fetchCurrentDirListing()
                } label: {
                    BorderedButtonView(button: (backgroundColor: .yellow, borderColor: .black),
                                       label: (label: "LIST", labelColor: .black),
                                       badge: nil,
                                       disabled: !hasOpenConnection,
                                       emphasized: false)
                }

                Button {
                    getCurrentWorkingDirectory()
                } label: {
                    BorderedButtonView(button: (backgroundColor: .yellow, borderColor: .black),
                                       label: (label: "PWD", labelColor: .black),
                                       badge: nil,
                                       disabled: !hasOpenConnection,
                                       emphasized: false)
                }
                
                Button {
                    showAskForDirectory = true
                } label: {
                    BorderedButtonView(button: (backgroundColor: .yellow, borderColor: .black),
                                       label: (label: "CWD", labelColor: .black),
                                       badge: nil,
                                       disabled: !hasOpenConnection,
                                       emphasized: false)
                }

                Button {
                    changeToParentDirectory()
                } label: {
                    BorderedButtonView(button: (backgroundColor: .yellow, borderColor: .black),
                                       label: (label: "CDUP", labelColor: .black),
                                       badge: nil,
                                       disabled: !hasOpenConnection,
                                       emphasized: false)
                }

                Button {
                    showAskForUploadFile = true
                } label: {
                    BorderedButtonView(button: (backgroundColor: .yellow, borderColor: .black),
                                       label: (label: "STOR", labelColor: .black),
                                       badge: nil,
                                       disabled: !hasOpenConnection,
                                       emphasized: false)
                }
            }

            Divider()

            BorderedLoggingView(lines: $logLines)
                .font(Font.custom("IBM 3270 Condensed", size: 12))
            
            Spacer()
        }
        .fileImporter(isPresented: $showAskForUploadFile, allowedContentTypes: [.data]) { result in
            switch result {
            case .success(let url):
                uploadFile(url)
            case .failure(let error):
                print("ERROR! \(error)")
            }
        }
        .overlay(content: {
            if showConnectionError, let error = connectionError {
                BorderedInfoView(
                    icon: (icon: .error, backgroundColor: .red),
                    label: (label: "An error occurred while connecting to the FTP server:", labelColor: .black),
                    subLabel: (label: "URL: \(fullServerURL?.absoluteString ?? "Unknown")\n\nError: \(error.debugDescription)", labelColor: .black),
                    dismiss: (label: "Dismiss", labelColor: .black, backgroundColor: .yellow),
                    autoDismiss: nil,
                    action: {
                        showConnectionError = false
                        self.connectionError = nil
                    })
            }
            else if showConnectionOpening {
                BorderedProgressView(label: ("Attempting connecting to:", .black),
                                     subLabel: (fullServerURL?.absoluteString ?? "Unknown", .black))
            }
            else if showConnectionClosing {
                BorderedProgressView(label: ("Disconnecting from:", .black),
                                     subLabel: (fullServerURL?.absoluteString ?? "Unknown", .black))
            }
            else if showConnectionOpened {
                BorderedInfoView(
                    icon: (icon: .info, backgroundColor: .white),
                    label: (label: "Connection succeeded", labelColor: .black),
                    subLabel: nil,
                    dismiss: (label: "Dismiss", labelColor: .black, backgroundColor: .yellow),
                    autoDismiss: (seconds: 5, labelColor: .white, backgroundColor: .brown),
                    action: {
                        self.connectionError = nil
                        self.showConnectionOpened = false
                    })
            }
            else if showAskForDirectory {
                BorderedChooserView(choices: $directories,
                                    selected: $directoryToChangeTo,
                                    icon: (icon: .question, backgroundColor: .white),
                                    label: (label: "Choose a folder", labelColor: .black),
                                    subLabel: nil,
                                    ok: (label: "Ok", labelColor: .black, backgroundColor: .yellow, action: {
                    changeWorkingDirectory(directoryToChangeTo)
                    directoryToChangeTo = ""
                    self.showAskForDirectory = false
                }), cancel: (label: "Cancel", labelColor: .black, backgroundColor: .yellow, action: {
                    directoryToChangeTo = ""
                    self.showAskForDirectory = false
                }))
            }
        })
    }

    private func createAndOpenFTPSession(url: URL, dataConnectionMode: FTPDataConnectionMode) {

        logLines.append("[creating session with url \(url.absoluteString)]")
        ftpClientSession = FTPClientLib.createSession(url: url)
        
        if let ftpClientSession {
            
            showConnectionOpening = true
            
            let connectionMode = self.dataConnectionMode

            Task {
                logLines.append("[setting data connection mode to \(self.dataConnectionMode)]")
                await ftpClientSession.setDataConnectionMode(connectionMode)
                
                do {
                    logLines.append("[connecting to \(url.absoluteString)]")
                    openResult = try await ftpClientSession.open()
                }
                catch {

                    connectionError = error as? FTPError
                    hasOpenConnection = false

                    showConnectionOpening = false
                    showConnectionOpened = false
                    showConnectionError = true
                    
                    logLines.append("[connection error: \(error)]")

                    return
                }
                
                hasOpenConnection = true

                showConnectionOpening = false
                showConnectionOpened = true
                showConnectionError = false

                if let openResult {

                    logLines.append("[connected successfully]")
                    if let welcome = await openResult.welcomeMessage {
                        logLines.append("[server welcomes you]")
                        logLines.append(welcome)
                    }
                }
            }
        }
    }
    
    private func closeFTPSession() {
        if let ftpClientSession {
            Task {
                showConnectionClosing = true
                
                logLines.append("[disconnecting from \(await ftpClientSession.serverURL.absoluteString)]")
                try await ftpClientSession.close()
                logLines.append("[disconnected]")

                hasOpenConnection = false
                
                showConnectionClosing = false
            }
        }
    }
    
    private func login(username: String, password: String) {
        if let ftpClientSession {
            Task {
                do {
                    logLines.append("[logging in as \(username)]")
                    let result = try await ftpClientSession.login(username: username, password: password)
                    logLines.append("[login result is \(await result.result) (\(await result.code != nil ? "\(await result.code!)" : "nil"),\"\(await result.message ?? "nil")\")]")
                    
                    if await result.result == .success {
                        getCurrentWorkingDirectory()
                        fetchCurrentDirListing()
                    }
                    else {
                        connectionError = FTPError(FTPError.FTPErrorCode.unknown, userinfo: [NSLocalizedDescriptionKey : "Login failed with message: \(await result.message ?? "nil")"])
                    }
                }
                catch {
                    connectionError = error as? FTPError
                    showConnectionError = true
                }
            }
        }
    }
    
    private func getCurrentWorkingDirectory() {
        if let ftpClientSession {
            Task {
                do {
                    logLines.append("[fetching current working directory]")
                    let result = try await ftpClientSession.printWorkingDirectory()
                    logLines.append("\(await result.workingDirectory ?? "nil")")
                }
                catch {
                    connectionError = error as? FTPError
                    showConnectionError = true
                }
            }
        }
    }
    
    private func changeWorkingDirectory(_ directory: String) {
        if let ftpClientSession {
            Task {
                do {
                    logLines.append("[changing working directory to \(directory)]")
                    let result = try await ftpClientSession.changeWorkingDirectory(directory: directory)
                    logLines.append("\(await result.message ?? "nil")")
                    
                    getCurrentWorkingDirectory()
                    fetchCurrentDirListing()
                }
                catch {
                    connectionError = error as? FTPError
                    showConnectionError = true
                }
            }
        }
    }

    private func changeToParentDirectory() {
        if let ftpClientSession {
            Task {
                do {
                    logLines.append("[changing working directory to parent]")
                    let result = try await ftpClientSession.changeToParentDirectory()
                    logLines.append("\(await result.message ?? "nil")")
                    
                    getCurrentWorkingDirectory()
                    fetchCurrentDirListing()
                }
                catch {
                    connectionError = error as? FTPError
                    showConnectionError = true
                }
            }
        }
    }
    
    private func fetchCurrentDirListing() {
        if let ftpClientSession {
            Task {
                do {
                    logLines.append("[fetching current directory listing]")
                    let result = try await ftpClientSession.list()
                    if await result.result == .success {
                        logLines.append("[success]")
                        if let files = await result.files, files.count > 0 {
                            for file in files {
                                let unixType = String(file.unixFiletype.rawValue)
                                let userModeString = file.unixUserModeBits.map({ String($0.rawValue)}).joined()
                                let groupModeString = file.unixGroupModeBits.map({ String($0.rawValue)}).joined()
                                let otherModeString = file.unixOtherModeBits.map({ String($0.rawValue)}).joined()
                                let fileString = String(format: "%@ %3@ %3@ %3@ %10d %30@",
                                                        unixType,
                                                        userModeString,
                                                        groupModeString,
                                                        otherModeString,
                                                        file.sizeInBytes,
                                                        file.filename)
                                logLines.append(fileString)
                            }
                            
                            directories = await result.foldersOnly(includingDotFolders: false)?.compactMap({$0.filename}) ?? []
                            directoryToChangeTo = directories.first ?? ""
                        }
                        else {
                            logLines.append("Empty folder")
                        }
                    }
                    else {
                        logLines.append("[failure: (\(await result.code != nil ? "\(await result.code!)" : "nil"),\"\(await result.message ?? "nil")\"]")
                    }
                }
                catch {
                    connectionError = error as? FTPError
                    showConnectionError = true
                }
            }
        }
    }
    
    private func uploadFile(_ fileURL: URL) {
        guard let ftpClientSession else { return }
        
        Task {
            do {
                logLines.append("[uploading file: \(fileURL.lastPathComponent)]")
                let result = try await ftpClientSession.storeFile(fileURL: fileURL)
                switch await result.result {
                case .success:
                    logLines.append("[successfully uploaded: \(await result.message)]")
                    getCurrentWorkingDirectory()
                    fetchCurrentDirListing()
                case .failure:
                    logLines.append("[failed to upload: \(await result.message)]")
                default:
                    break
                }
                    
            }
            catch {
                connectionError = error as? FTPError
                showConnectionError = true
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
