//
//  BorderedSecureTextField.swift
//  FTPClient
//
//  Created by Peter de Vroomen on 22-02-2026.
//

import SwiftUI

struct BorderedSecureTextField: View {
    let placeHolder: String
    @Binding var text: String
    
    @State private var isSecureText = true
    @State private var internalText: String = ""
    
    var body: some View {
        ZStack(alignment: .trailing) {
            BorderedSecureUIKitTextField(placeHolder: placeHolder, text: $internalText, isSecure: $isSecureText)
                .frame(height: 22)
                .padding(.horizontal, 4)
                .background(.gray.opacity(0.2))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.black, lineWidth: 1)
                )
                .onAppear {
                    print("BorderedSecureTextField:.onAppear with text: \(text)")
                    sync(with: text)
                }
                .onChange(of: internalText) { _, newValue in
                    print("BorderedSecureTextField:.onChange of internalText: \(internalText), newValue: \(newValue), text: \(text)")
                    sync(with: newValue)
                }
                .onChange(of: text) { _, newValue in
                    print("BorderedSecureTextField:.onChange of text: \(text), newValue: \(newValue), internalText: \(internalText)")
                    sync(with: newValue)
                }

            Button {
                isSecureText.toggle()
            } label: {
                Image(systemName: isSecureText ? "eye" : "eye.slash")
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.gray)
                    .frame(width: 16, height: 16)
            }
            .padding(8)
        }
    }
    
    private func sync(with newValue: String) {
        if internalText != newValue {
            internalText = newValue
        }
        if text != newValue {
            text = newValue
        }
    }
}

struct BorderedSecureUIKitTextField: UIViewRepresentable {
    let placeHolder: String
    @Binding var text: String
    @Binding var isSecure: Bool
    
    private let uuid: Int = UUID().hashValue
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.isSecureTextEntry = isSecure
        textField.text = text
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.textContentType = .newPassword
        textField.attributedPlaceholder = NSAttributedString(string: placeHolder, attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        textField.delegate = context.coordinator
        textField.tag = uuid
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.tag == uuid {
            uiView.isSecureTextEntry = isSecure
            print("BorderedSecureUIKitTextField: updateUIView with text: \(text)")
            uiView.text = text
            uiView.frame.size.height = 40
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: BorderedSecureUIKitTextField
        
        init(_ parent: BorderedSecureUIKitTextField) {
            self.parent = parent
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            if textField.tag == parent.uuid {
                parent.text = textField.text ?? ""
            }
        }
    }
}
