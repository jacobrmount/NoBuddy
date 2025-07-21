import Foundation

/// Debug helper for Notion API integration issues
class NotionDebugHelper {
    
    static func logJSONData(_ data: Data, label: String) {
        if let jsonString = String(data: data, encoding: .utf8) {
            print("[\(label)] JSON Data:")
            print(jsonString)
            
            // Try to pretty print if possible
            if let jsonObject = try? JSONSerialization.jsonObject(with: data),
               let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                print("[\(label)] Pretty JSON:")
                print(prettyString)
            }
        } else {
            print("[\(label)] Could not convert data to string")
        }
    }
    
    static func testTokenFormat(_ token: String) -> Bool {
        // Test Notion token formats
        let secretPattern = "^secret_[A-Za-z0-9]{43}$"
        let internalPattern = "^ntn_[A-Za-z0-9]{46}$"
        
        let secretRegex = try? NSRegularExpression(pattern: secretPattern)
        let internalRegex = try? NSRegularExpression(pattern: internalPattern)
        
        let range = NSRange(location: 0, length: token.utf16.count)
        
        let isValidSecret = secretRegex?.firstMatch(in: token, options: [], range: range) != nil
        let isValidInternal = internalRegex?.firstMatch(in: token, options: [], range: range) != nil
        
        print("[NotionDebug] Token format test:")
        print("- Token length: \(token.count)")
        print("- Starts with 'secret_': \(token.hasPrefix("secret_"))")
        print("- Starts with 'ntn_': \(token.hasPrefix("ntn_"))")
        print("- Valid secret format: \(isValidSecret)")
        print("- Valid internal format: \(isValidInternal)")
        
        return isValidSecret || isValidInternal
    }
    
    static func validateAPIResponse(data: Data, expectedType: String) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("[NotionDebug] API Response validation:")
                print("- Has 'object' field: \(json["object"] != nil)")
                if let objectType = json["object"] as? String {
                    print("- Object type: '\(objectType)'")
                    print("- Expected type: '\(expectedType)'")
                    print("- Type matches: \(objectType == expectedType)")
                }
                
                print("- Has 'id' field: \(json["id"] != nil)")
                print("- Has 'results' field: \(json["results"] != nil)")
                
                if let results = json["results"] as? [[String: Any]] {
                    print("- Results count: \(results.count)")
                    for (index, result) in results.enumerated() {
                        if let objType = result["object"] as? String {
                            print("- Result \(index) type: '\(objType)'")
                        }
                    }
                }
            }
        } catch {
            print("[NotionDebug] Failed to parse JSON: \(error)")
        }
    }
}