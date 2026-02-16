//
//  BorderedTextInputView.swift
//  FTPClient
//
//  Created by Peter de Vroomen on 16-12-2025.
//

import SwiftUI
internal import Combine

struct BorderedChooserView: View {
    
    enum Icon: String {
        case undetermined = "ellipsis.rectangle"
        case question = "questionmark.square"
        case info = "info.square"
        case warning = "exclamationmark.triangle"
        case error = "exclamationmark.octagon"
    }
    
    @Binding
    var choices: [String]
    @Binding
    var selected: String
    
    let icon: (icon: Icon, backgroundColor: Color)
    let label: (label: String, labelColor: Color)
    let subLabel: (label: String, labelColor: Color)?
    let ok: (label: String, labelColor: Color, backgroundColor: Color, action: () -> Void)
    let cancel: (label: String, labelColor: Color, backgroundColor: Color, action: () -> Void)?
    
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var body: some View {

        ZStack {
            Rectangle()
                .background(.ultraThickMaterial.opacity(0.7))
                .disabled(true)

            HStack {
                Spacer(minLength: 32)
                
                VStack {
                    
                    HStack {
                        
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
                            .frame(width: 16)
                        
                        Text(label.label)
                            .foregroundStyle(label.labelColor)
                            .fontWeight(.heavy)
                            .lineLimit(3)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .init(horizontal: .leading, vertical: .center))
                        
                    }

                    Spacer()
                        .frame(height: 8)

                    if let subLabel {
                        Spacer()
                            .frame(height: 8)
                        
                        Text(subLabel.label)
                            .font(.caption2)
                            .foregroundStyle(subLabel.labelColor)
                            .fontWeight(.medium)
                            .lineLimit(12)
                            .multilineTextAlignment(.center)
                        
                        Spacer()
                            .frame(height: 16)
                    }
                    
                    Picker("Choice", selection: $selected) {
                        ForEach(choices.sorted(), id: \.self) { choice in
                            Text(choice).tag(choice)
                        }
                    }
                    .pickerStyle(.wheel)
                    .padding(.vertical, -16)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.black, lineWidth: 2)
                            .fill(Color(.white))
                            .shadow(color: .black, radius: 3, x: 2, y: 2  )
                    }

                    Spacer()
                        .frame(height: 16)
                    
                    HStack {
                        
                        if let cancel {
                            
                            Button {
                                cancel.action()
                            } label: {
                                BorderedButtonView(button: (.yellow, .black),
                                                   label: (cancel.label, .black),
                                                   badge: nil,
                                                   disabled: false,
                                                   emphasized: false)
                            }
                        }
                            
                        Spacer()
                        
                        Button {
                            ok.action()
                        } label: {
                            BorderedButtonView(button: (.yellow, .black),
                                               label: (ok.label, .black),
                                               badge: nil,
                                               disabled: false,
                                               emphasized: true)
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
    @Previewable @State
    var choices: [String] = [".", "..", "uploads", "Documents", "Music", "Pictures", "Downloads", "Desktop", "Library", "Movies", "Books", "Games", "Cloud Storage"]
    @Previewable @State
    var choice: String = "uploads"
    
    BorderedChooserView(
        choices: $choices,
        selected: $choice,
        icon: (icon: .question, backgroundColor: .white),
        label: (label: "Choose directory name", labelColor: .black),
        subLabel: (label: "Choose the name of the directory you want to change to.", labelColor: .black),
        ok: (label: "Ok", labelColor: .black, backgroundColor: .yellow, action: {}),
        cancel: (label: "Cancel", labelColor: .black, backgroundColor: .yellow, action: {}))
}
