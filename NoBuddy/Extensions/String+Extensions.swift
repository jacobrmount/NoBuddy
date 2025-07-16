import Foundation

extension String {
    
    /// Validate if string is a valid Notion token format
    var isValidNotionToken: Bool {
        // Notion tokens start with "secret_" and are followed by 43 characters
        let pattern = "^secret_[A-Za-z0-9]{43}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: self.count)
        return regex?.firstMatch(in: self, options: [], range: range) != nil
    }
    
    /// Remove whitespace and newlines from both ends
    var trimmed: String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Check if string is empty after trimming
    var isEmptyOrWhitespace: Bool {
        self.trimmed.isEmpty
    }
    
    /// Truncate string to a maximum length with optional ellipsis
    func truncated(to length: Int, withEllipsis: Bool = true) -> String {
        if self.count <= length {
            return self
        }
        
        let endIndex = self.index(self.startIndex, offsetBy: length)
        let truncated = String(self[..<endIndex])
        
        return withEllipsis ? truncated + "..." : truncated
    }
    
    /// Mask sensitive information (like tokens) for display
    var masked: String {
        guard self.count > 8 else { return "****" }
        
        let prefix = self.prefix(4)
        let suffix = self.suffix(4)
        let middle = String(repeating: "*", count: max(4, self.count - 8))
        
        return "\(prefix)\(middle)\(suffix)"
    }
    
    /// Convert to safe filename
    var safeFilename: String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return self.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
    
    /// Extract domain from URL string
    var domain: String? {
        guard let url = URL(string: self) else { return nil }
        return url.host
    }
}