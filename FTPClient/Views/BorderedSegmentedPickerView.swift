//
//  BorderedSegmentedPickerView.swift
//  FTPClient
//
//  Created by Peter de Vroomen on 09-01-2026.
//

import SwiftUI

struct BorderedSegmentedPickerView<T>: View where T: Hashable {
    
    let labels: [(label: String, value: T)]
    @Binding
    var selected: T
    let labelColor: Color
    let segment: (backgroundColor: Color, borderColor: Color)
    let disabled: Bool
    let didSelect: ((T) -> Void)?
    
    var body: some View {
        VStack {
            HStack(spacing: 0) {
                ForEach(labels, id: \.self.value) { label in
                    if label.value == selected {
                        PickerSegmentView(label: (label: label.label, labelColor: labelColor),
                                          segment: segment,
                                          selected: true,
                                          disabled: disabled)
                    }
                    else {
                        PickerSegmentView(label: (label: label.label, labelColor: labelColor),
                                          segment: segment,
                                          selected: false,
                                          disabled: disabled)
                        .onTapGesture {
                            withAnimation(Animation.easeInOut) {
                                if !disabled {
                                    selected = label.value
                                    if let didSelect {
                                        didSelect(label.value)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(0)
            .background(disabled ? segment.backgroundColor.opacity(0.3) : segment.backgroundColor)
            .cornerRadius(6)
            .shadow(color: .black, radius: 3, x: 2, y: 2  )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(disabled ? segment.borderColor.opacity(0.3) : segment.borderColor, lineWidth: 2)
            )
        }
    }
}

struct PickerSegmentView: View {
    
    let label: (label: String, labelColor: Color)
    let segment: (backgroundColor: Color, borderColor: Color)
    let selected: Bool
    let disabled: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .foregroundStyle(selected
                                 ? (disabled ? .gray.opacity(0.6) : segment.backgroundColor)
                                 : .gray.opacity(disabled ? 0.7 : 0.3))
                .cornerRadius(6)
                .layoutPriority(-100)
            
            HStack {
                Text(label.label)
                    .foregroundStyle(selected
                                     ? (disabled ? label.labelColor.opacity(0.3) : label.labelColor)
                                     : label.labelColor.opacity(disabled ? 0.1 : 0.5))
                    .padding(.all, 8)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(height: 22)
            }
        }
        .background(segment.backgroundColor)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(selected
                        ? (disabled ? segment.borderColor.opacity(0.3) : segment.borderColor)
                        : segment.borderColor.opacity(disabled ? 0.1 : 0.3),
                       lineWidth: 2)
        )
    }
}

#Preview {
    @Previewable @State
    var selectedLabel: Int = 2
    @Previewable @State
    var disabled: Bool = false

    let labels: [(String, Int)] = [("Picard", 0), ("Riker", 1), ("Laforge", 2), ("Data", 3)]

    BorderedSegmentedPickerView<Int>(labels: labels,
                                     selected: $selectedLabel,
                                     labelColor: .black,
                                     segment: (.yellow, .black),
                                     disabled: disabled,
                                     didSelect: nil)
}
