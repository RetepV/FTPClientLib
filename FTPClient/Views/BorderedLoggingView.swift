//
//  BorderedLoggingView.swift
//  FTPClient
//
//  Created by Peter de Vroomen on 29-12-2025.
//

import SwiftUI

struct BorderedLoggingView: View {
    
    let backgroundColor: Color = Color(red: 0.2, green: 0.2, blue: 0.2)
    let borderColor: Color = .black
    let textColor: Color = .green

    @Binding
    var lines: [String]
    
    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing:0) {
                if lines.isEmpty {
                    Text("")
                        .foregroundStyle(textColor)
                        .frame(maxWidth: .infinity, alignment: .init(horizontal: .leading, vertical: .top))
                        .multilineTextAlignment(.leading)
                }
                else {
                    ForEach(lines.indices, id: \.self) { index in
                        Text(lines[index])
                            .foregroundStyle(textColor)
                            .frame(maxWidth: .infinity, alignment: .init(horizontal: .leading, vertical: .top))
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
        .defaultScrollAnchor(.top, for: .initialOffset)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
        .background(backgroundColor)
        .cornerRadius(6)
        .shadow(color: .black, radius: 3, x: 2, y: 2  )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(.black, lineWidth: 2)
        )
        .padding(.horizontal, 8)
    }
}

#Preview {
    
    @Previewable @State
    var logLines: [String] = [
        "             |\\      _,,,---,,_",
        "        ZZZzz /,`.-'`'    -.  ;-;;,_",
        "             |,4-  ) )-,_. ,\\ (  `'-'",
        "            '---''(_/--'  `-'\\_)",
        "",
        "             Sporos Tech ₍^•_•^₎ﾉ",
        "",
        "          Welcome to our FTP server!",
        "    This server allows anonymous logins with",
        "      either username 'anonymous' or 'ftp'.",
        "     Type anything for the password, but I",
        "      would appreciate it if you typed an",
        "        email addres through which I can",
        "       reach you if necessary. Up to you.",
        "      This is just a hobby for me, please",
        "     don't break this server. Please don't",
        "     make me waste hours of my life to set",
        "     it all back up again. I know you can",
        "          do that any time you want.",
        ""
    ]

    BorderedLoggingView(lines: $logLines)
        .font(Font.custom("IBM 3270 Condensed", size: 14))
}
