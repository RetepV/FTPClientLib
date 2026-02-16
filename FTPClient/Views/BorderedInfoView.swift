//
//  BorderedInfoView.swift
//  FTPClient
//
//  Created by Peter de Vroomen on 16-12-2025.
//

import SwiftUI
internal import Combine

struct BorderedInfoView: View {
    
    enum Icon: String {
        case undetermined = "ellipsis.rectangle"
        case question = "questionmark.square"
        case info = "info.square"
        case warning = "exclamationmark.triangle"
        case error = "exclamationmark.octagon"
    }
    
    let icon: (icon: Icon, backgroundColor: Color)
    let label: (label: String, labelColor: Color)
    let subLabel: (label: String, labelColor: Color)?
    let dismiss: (label: String, labelColor: Color, backgroundColor: Color)
    @State
    var autoDismiss: (seconds: Int, labelColor: Color, backgroundColor: Color)?
    let action: () -> Void
    
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var body: some View {

        ZStack {
            Rectangle()
                .background(.ultraThickMaterial.opacity(0.7))
                .disabled(true)

            HStack {
                Spacer(minLength: 32)
                
                VStack {
                    
                    ZStack {
                        icon.backgroundColor
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        
                        Image(systemName: icon.icon.rawValue)
                            .resizable()
                            .frame(width: 40, height: 40)
                            .shadow(color: .black, radius: 4, x: 2, y: 2)
                    }
                    
                    Spacer()
                        .frame(height: 32)
                    
                    Text(label.label)
                        .foregroundStyle(label.labelColor)
                        .fontWeight(.heavy)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                    
                    
                    if let subLabel {
                        Spacer()
                            .frame(height: 16)
                        
                        Text(subLabel.label)
                            .foregroundStyle(subLabel.labelColor)
                            .fontWeight(.medium)
                            .lineLimit(12)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                        .frame(height: 32)
                    
                    HStack {
                        
                        Spacer()
                        
                        Button {
                            action()
                        } label: {
                            BorderedButtonView(button: (.yellow, .black),
                                               label: ("Dismiss", .black),
                                               badge: autoDismiss != nil ? ("\(autoDismiss!.seconds)",
                                                                            autoDismiss!.backgroundColor,
                                                                            autoDismiss!.labelColor) : nil,
                                               disabled: false,
                                               emphasized: false)
                            .onReceive(timer) { _ in
                                if autoDismiss != nil {
                                    if autoDismiss!.seconds > 1 {
                                        autoDismiss!.seconds -= 1
                                    }
                                    else {
                                        autoDismiss = nil
                                        action()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
                .background(.white)
                .cornerRadius(6)
                .shadow(color: .black, radius: 6, x: 3, y: 3  )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.black, lineWidth: 2)
                )
                
                Spacer(minLength: 32)
            }
        }
        .ignoresSafeArea(edges: .all)
    }
}

#Preview {
    BorderedInfoView(
        icon: (icon: .info, backgroundColor: .red),
        label: (label: "Something went wrong!", labelColor: .black),
        subLabel: (label: "We actually don't know what to do, but we'll try to help you through it! Please hang tight, we'll be there in a jiffy!", labelColor: .black),
        dismiss: (label: "Dismiss", labelColor: .black, backgroundColor: .yellow),
        autoDismiss: (seconds: 10, labelColor: .white, backgroundColor: .brown),
        action: {
        })
}
