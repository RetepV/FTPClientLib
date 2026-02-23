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
let defaultUserName = "demo"
let defaultUserPassword = "demo"
let defaultServerPort = "21"

struct ContentView: View {
    
    enum FocusedTextField {
        case serverName
        case serverPort
        case userName
        case userPassword
    }
    
    struct FileImporterContext {
        let allowedContentTypes: [UTType]
        let onCompletion: (Result<URL, Error>) -> Void
    }
    
    @FocusState private var focusedField: FocusedTextField?
    
    @State private var ftpClientSession: FTPClientSession? = nil
    
    @State private var showConnectionOpening: Bool = false
    @State private var showConnectionOpened: Bool = false
    @State private var showConnectionClosing: Bool = false
    @State private var showConnectionError: Bool = false
    @State private var showDownloadError: Bool = false
    @State private var showAskForDirectory: Bool = false
    @State private var showAskForRemoteDownloadFile: Bool = false
    @State private var showDownloadSucceeded: Bool = false

    @State private var filesInCurrentDirectory: [String] = []
    @State private var directoriesInCurrentDirectory: [String] = []

    @State private var showFileImporter: Bool = false
    @State private var fileImporterContext: FileImporterContext = FileImporterContext(allowedContentTypes: [], onCompletion: { _ in })

    @State private var directoryToChangeTo: String = ""
    @State private var remoteFileToDownload: String = ""

    @State private var hasOpenConnection: Bool = false
    @State private var isLoggedIn: Bool = false

    @State private var openResult: FTPSessionOpenResult? = nil
    
    @State private var connectionError: FTPError? = nil
    @State private var downloadError: FTPError? = nil
    
    @State private var serverName: String = ""
    @State private var serverPort: String = ""
    @State private var userName: String = ""
    @State private var userPassword: String = ""

    @State private var filePath: String = ""
    
    @State private var logLines: [String] = []
    
    @State private var dataConnectionModes: [(String, FTPDataConnectionMode)] = [("Active", .active), ("Passive", .passive)]
    @State private var dataConnectionMode: FTPDataConnectionMode = .active
    
    @State private var dataTransferTypes: [(String, FTPTypeCode)] = [("IMAGE", .image), ("ASCII", .ascii)]
    @State private var dataTransferType: FTPTypeCode = .image
    
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
                            .frame(width: 100, alignment: Alignment.leading)
                        BorderedTextField(placeHolder: defaultServerName, text: $serverName)
                            .focused($focusedField, equals: .serverName)
                    }
                    
                    HStack(alignment: .center) {
                        Text("Port:")
                            .frame(width: 100, alignment: Alignment.leading)
                        BorderedTextField(placeHolder: defaultServerPort, text: $serverPort)
                            .frame(width: 50)
                            .focused($focusedField, equals: .serverPort)
                    }
                    
                    HStack(alignment: .center) {
                        Text("Username:")
                            .frame(width: 100, alignment: Alignment.leading)
                        BorderedTextField(placeHolder: defaultUserName, text: $userName)
                            .focused($focusedField, equals: .userName)
                    }

                    HStack(alignment: .center) {
                        Text("Password:")
                            .frame(width: 100, alignment: Alignment.leading)
                        BorderedTextField(placeHolder: defaultUserPassword, text: $userPassword)
                            .focused($focusedField, equals: .userPassword)
                    }

                    HStack(alignment: .center) {
                        Text("Connection mode: ")
                        
                        Spacer()
                        
                        BorderedSegmentedPickerView<FTPDataConnectionMode>(labels: dataConnectionModes,
                                                                           selected: $dataConnectionMode,
                                                                           labelColor: .black,
                                                                           segment: (.yellow, .black),
                                                                           disabled: hasOpenConnection,
                                                                           didSelect: { _ in
                            focusedField = nil
                        })
                    }
                    
                    HStack() {

                        Button {
                            focusedField = nil
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
                            focusedField = nil
                            Task {
                                let sessionState = await ftpClientSession?.sessionState
                                if let sessionState, (sessionState == .opened) || (sessionState == .idle) {
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
                                                
                        Spacer()

                        Button {
                            focusedField = nil
                            if userName.isEmpty {
                                userName = defaultUserName
                            }
                            if userPassword.isEmpty {
                                userPassword = defaultUserPassword
                            }
                            login(username: userName, password: userPassword)
                        } label: {
                            BorderedButtonView(button: (backgroundColor: .yellow, borderColor: .black),
                                               label: (label: "Login", labelColor: .black),
                                               badge: nil,
                                               disabled: !hasOpenConnection || isLoggedIn,
                                               emphasized: false)
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            Divider()

            HStack {
                Text("Data transfer type: ")
                
                Spacer()
                
                BorderedSegmentedPickerView<FTPTypeCode>(labels: dataTransferTypes,
                                                         selected: $dataTransferType,
                                                         labelColor: .black,
                                                         segment: (.yellow, .black),
                                                         disabled: !isLoggedIn,
                                                         didSelect: { type in
                    focusedField = nil
                    setTransferType(type)
                })
            }
            .padding(Edge.Set.horizontal, 16)
            
            Divider()
            
            VStack {
                HStack {
                    Button {
                        focusedField = nil
                        fetchCurrentDirListing()
                    } label: {
                        BorderedButtonView(button: (backgroundColor: .yellow, borderColor: .black),
                                           label: (label: "LIST", labelColor: .black),
                                           badge: nil,
                                           disabled: !isLoggedIn,
                                           emphasized: false)
                    }
                    
                    Button {
                        focusedField = nil
                        getCurrentWorkingDirectory()
                    } label: {
                        BorderedButtonView(button: (backgroundColor: .yellow, borderColor: .black),
                                           label: (label: "PWD", labelColor: .black),
                                           badge: nil,
                                           disabled: !isLoggedIn,
                                           emphasized: false)
                    }
                    
                    Button {
                        focusedField = nil
                        showAskForDirectory = true
                    } label: {
                        BorderedButtonView(button: (backgroundColor: .yellow, borderColor: .black),
                                           label: (label: "CWD", labelColor: .black),
                                           badge: nil,
                                           disabled: !isLoggedIn,
                                           emphasized: false)
                    }
                    
                    Button {
                        focusedField = nil
                        changeToParentDirectory()
                    } label: {
                        BorderedButtonView(button: (backgroundColor: .yellow, borderColor: .black),
                                           label: (label: "CDUP", labelColor: .black),
                                           badge: nil,
                                           disabled: !isLoggedIn,
                                           emphasized: false)
                    }
                    
                    Button {
                        focusedField = nil
                        sendNoOperation()
                    } label: {
                        BorderedButtonView(button: (backgroundColor: .yellow, borderColor: .black),
                                           label: (label: "NOOP", labelColor: .black),
                                           badge: nil,
                                           disabled: !isLoggedIn,
                                           emphasized: false)
                    }
                    
                    Spacer()
                }
                .padding(Edge.Set.horizontal, 16)

                Divider()

                HStack {
                                        
                    Button {
                        focusedField = nil
                        fileImporterContext = FileImporterContext(allowedContentTypes: [.data], onCompletion: { result in
                            switch result {
                            case .success(let url):
                                uploadFile(url)
                            case .failure(let error):
                                print("ERROR! \(error)")
                            }
                        })
                        showFileImporter = true
                    } label: {
                        BorderedButtonView(button: (backgroundColor: .yellow, borderColor: .black),
                                           label: (label: "STOR", labelColor: .black),
                                           badge: nil,
                                           disabled: !isLoggedIn,
                                           emphasized: false)
                    }
                    
                    Button {
                        focusedField = nil
                        showAskForRemoteDownloadFile = true
                    } label: {
                        BorderedButtonView(button: (backgroundColor: .yellow, borderColor: .black),
                                           label: (label: "RETR", labelColor: .black),
                                           badge: nil,
                                           disabled: !isLoggedIn,
                                           emphasized: false)
                    }
                    
                    Spacer()
                }
                .padding(Edge.Set.horizontal, 16)
            }
            
            Divider()
            
            BorderedLoggingView(lines: $logLines)
                .font(Font.custom("IBM 3270 Condensed", size: 12))

            Color.clear
                .frame(height: 16)
            
            HStack {
                Spacer()

                Button {
                    focusedField = nil
                    logLines.removeAll()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.black)
                }
            }
            .padding(Edge.Set.horizontal, 16)
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: fileImporterContext.allowedContentTypes, onCompletion: fileImporterContext.onCompletion)
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
            else if showDownloadSucceeded {
                BorderedInfoView(
                    icon: (icon: .info, backgroundColor: .white),
                    label: (label: "Download of file \(remoteFileToDownload) succeeded", labelColor: .black),
                    subLabel: nil,
                    dismiss: (label: "Dismiss", labelColor: .black, backgroundColor: .yellow),
                    autoDismiss: (seconds: 5, labelColor: .white, backgroundColor: .brown),
                    action: {
                        self.downloadError = nil
                        self.showDownloadSucceeded = false
                    })
            }
            if showDownloadError, let error = downloadError {
                BorderedInfoView(
                    icon: (icon: .error, backgroundColor: .red),
                    label: (label: "An error occurred while downloading a file", labelColor: .black),
                    subLabel: (label: "\(remoteFileToDownload)\n\nError: \(error.debugDescription)", labelColor: .black),
                    dismiss: (label: "Dismiss", labelColor: .black, backgroundColor: .yellow),
                    autoDismiss: nil,
                    action: {
                        showDownloadError = false
                        self.downloadError = nil
                    })
            }
            else if showAskForDirectory {
                BorderedChooserView(choices: $directoriesInCurrentDirectory,
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
            else if showAskForRemoteDownloadFile {
                BorderedChooserView(choices: $filesInCurrentDirectory,
                                    selected: $remoteFileToDownload,
                                    icon: (icon: .question, backgroundColor: .white),
                                    label: (label: "Choose a file", labelColor: .black),
                                    subLabel: nil,
                                    ok: (label: "Ok", labelColor: .black, backgroundColor: .yellow, action: {
                    self.showAskForRemoteDownloadFile = false
                    // NOTE: On MacOS, use .directory to select a folder, on iOS we have to use .folder.
                    fileImporterContext = FileImporterContext(allowedContentTypes: [.folder], onCompletion: { result in
                        switch result {
                        case .success(let url):
                            downloadFile(remoteFileToDownload, localFileURL: url)
                        case .failure(let error):
                            print("ERROR! \(error)")
                        }
                    })
                    showFileImporter = true
                }), cancel: (label: "Cancel", labelColor: .black, backgroundColor: .yellow, action: {
                    remoteFileToDownload = ""
                    self.showAskForRemoteDownloadFile = false
                }))
            }
        })
        .task {
            atStart();
        }
    }
    
    private func atStart() {
        logLines.append("01234567890123456789012345678901234567890123456789012345678901234567890123456789")
        logLines.append("          1         2         3         4         5         6         7")
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
                    isLoggedIn = false
                    
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
                
                logLines.append("[connected successfully]")

                if let openResult {
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
                isLoggedIn = false
                
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
                        isLoggedIn = true
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
                    isLoggedIn = false
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
    
    private func sendNoOperation() {
        if let ftpClientSession {
            Task {
                do {
                    logLines.append("[sending 'no operation']")
                    let result = try await ftpClientSession.noOperation()
                    logLines.append("\(await result.message ?? "nil")")
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
                            
                            directoriesInCurrentDirectory = await result.foldersOnly(includingDotFolders: false)?.compactMap({$0.filename}) ?? []
                            filesInCurrentDirectory = await result.filesOnly()?.compactMap({$0.filename}) ?? []
                            
                            directoryToChangeTo = directoriesInCurrentDirectory.first ?? ""     // -=-
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
    
    private func downloadFile(_ remotePath: String, localFileURL: URL) {
        guard let ftpClientSession else { return }
        
        Task {
            do {
                var localFileURL = localFileURL
                if localFileURL.lastPathComponent != remotePath {
                    localFileURL = localFileURL.appending(component: remotePath, directoryHint: URL.DirectoryHint.notDirectory)
                }
                logLines.append("[downloading file (remote): \(remotePath), to (local): \(localFileURL)]")
                let result = try await ftpClientSession.retrieveFile(fileURL: localFileURL, remotePath: remotePath)
                switch await result.result {
                case .success:
                    logLines.append("[successfully downloaded file \(remotePath), message: \(await result.message)]")
                    getCurrentWorkingDirectory()
                    fetchCurrentDirListing()
                    showDownloadSucceeded = true
                case .failure:
                    logLines.append("[failed to download file \(remotePath), error: \(await result.message)]")
                    downloadError = FTPError(FTPError.FTPErrorCode.unknown, userinfo: [NSLocalizedDescriptionKey : "Download failed with message: \(await result.message ?? "nil")"])
                    showDownloadError = true
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
    
    private func setTransferType(_ type: FTPTypeCode) {
        if let ftpClientSession {
            Task {
                do {
                    logLines.append("[setting type code to \"\(type)\")]")
                    let result = try await ftpClientSession.setType(type)
                    switch await result.result {
                    case .success:
                        logLines.append("[success, type is now \"\(type)\", message: \(await result.message)]")
                    case .failure:
                        logLines.append("[failed to set type to \"\(type)\", error: \(await result.message)]")
                        downloadError = FTPError(FTPError.FTPErrorCode.unknown, userinfo: [NSLocalizedDescriptionKey : "Failed to set type to \"\(type)\", message: \(await result.message ?? "nil")"])
                        showDownloadError = true
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
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
