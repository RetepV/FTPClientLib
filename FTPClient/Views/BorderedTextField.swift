//
//  BorderedTextField.swift
//  FTPClient
//
//  Created by Peter de Vroomen on 22-02-2026.
//

import SwiftUI

struct BorderedTextField: View {
    let placeHolder: String
    @Binding var text: String
 
    @State private var internalText: String = ""

    var body: some View {
        BorderedUIKitTextField(placeHolder: placeHolder, text: $internalText)
            .frame(height: 22)
            .padding(.horizontal, 4)
            .background(.gray.opacity(0.2))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.black, lineWidth: 1)
            )
            .onAppear {
                print("BorderedTextField:.onAppear with text: \(text)")
                sync(with: text)
            }
            .onChange(of: internalText) { _, newValue in
                print("BorderedTextField:.onChange of internalText: \(internalText), newValue: \(newValue), text: \(text)")
                sync(with: newValue)
            }
            .onChange(of: text) { _, newValue in
                print("BorderedTextField:.onChange of text: \(text), newValue: \(newValue), internalText: \(internalText)")
                sync(with: newValue)
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

struct BorderedUIKitTextField: UIViewRepresentable {
    let placeHolder: String
    @Binding var text: String
    
    private let uuid: Int = UUID().hashValue

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.isSecureTextEntry = false
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
            print("BorderedUIKitTextField: updateUIView with text: \(text)")
            uiView.text = text
            uiView.frame.size.height = 40
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: BorderedUIKitTextField
        
        init(_ parent: BorderedUIKitTextField) {
            self.parent = parent
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            if textField.tag == parent.uuid {
                parent.text = textField.text ?? ""
            }
        }
    }
}
