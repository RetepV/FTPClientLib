//
//  BorderedProgressView.swift
//  FTPClient
//
//  Created by Peter de Vroomen on 16-12-2025.
//

import SwiftUI

struct BorderedProgressView: View {
    
    let label: (label: String, labelColor: Color)
    let subLabel: (label: String, labelColor: Color)?
    
    var body: some View {
        
        ZStack {
            Rectangle()
                .background(.ultraThickMaterial.opacity(0.7))
                .disabled(true)

            ProgressView {
                VStack {
                    Spacer()
                        .frame(height: 8)
                    
                    Text(label.label)
                        .foregroundStyle(label.labelColor)
                        .fontWeight(.bold)
                    
                    Spacer()
                        .frame(height: 12)
                    
                    if let subLabel {
                        Text(subLabel.label)
                            .foregroundStyle(subLabel.labelColor)
                            .font(Font.system(size: 14))
                            .fontWeight(.medium)
                    }
                }
            }
            .fixedSize(horizontal: true, vertical: true)
            .progressViewStyle(.circular)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(.white)
            .cornerRadius(6)
            .shadow(color: .black, radius: 6, x: 3, y: 3  )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.black, lineWidth: 2)
            )
        }
        .ignoresSafeArea(edges: .all)
    }
}

#Preview {
    BorderedProgressView(label: ("Loading", .black),
                         subLabel: ("Please wait...", .black))
}
