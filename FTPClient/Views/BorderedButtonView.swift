//
//  BorderedButtonView.swift
//  FTPClient
//
//  Created by Peter de Vroomen on 16-12-2025.
//

import SwiftUI

struct BorderedButtonView: View {
    
    let button: (backgroundColor: Color, borderColor: Color)
    let label: (label: String, labelColor: Color)
    let badge: (label: String, backgroundColor: Color, labelColor: Color)?
    let disabled: Bool
    let emphasized: Bool
    
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundStyle(disabled ? .gray.opacity(0.6) : button.backgroundColor)
                .cornerRadius(6)
                .layoutPriority(-100)

            HStack {
                Text(label.label)
                    .foregroundStyle(disabled ? label.labelColor.opacity(0.3) : label.labelColor)
                    .padding(.all, 8)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(height: 22)

                if !disabled, let badge {
                    Text(badge.label)
                        .font(.caption)
                        .padding(.horizontal, 4)
                        .background(disabled ? badge.backgroundColor.opacity(0.3) : badge.backgroundColor)
                        .foregroundStyle(badge.labelColor)
                        .clipShape(Capsule())
                        .offset(x: -8, y: 0)
                }
            }
        }
        .background(button.backgroundColor)
        .cornerRadius(6)
        .shadow(color: .black, radius: 3, x: 2, y: 2  )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(disabled ? button.borderColor.opacity(0.3) : button.borderColor, lineWidth: emphasized ? 4 : 2)
        )
        .disabled(disabled)
    }
}

#Preview {
    BorderedButtonView(button: (.yellow, .black),
                       label: ("Dismiss", .black),
                       badge: nil,
                       disabled: true,
                       emphasized: false)
}
