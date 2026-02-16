//
//  String+extension.swift
//  FTPClientLib
//
//  Created by Peter de Vroomen on 19-12-2025.
//

extension String {
    
    func firstIndex(of pattern: String) -> String.Index? {
        guard let range = self.range(of: pattern) else { return nil }
        return range.lowerBound
    }
}

