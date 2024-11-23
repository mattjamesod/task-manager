import CloudKit

enum CloudKitResponseError: Error {
    case notLoggedIn
    case cloud(CKError)
    case other(Error)
    
    static func wrapping(_ error: Error) -> CloudKitResponseError {
        guard let cloudError = error as? CKError else {
            return .other(error)
        }
        
        return wrapping(cloudError: cloudError)
    }
    
    private static func wrapping(cloudError: CKError) -> CloudKitResponseError {
        if cloudError.code == .accountTemporarilyUnavailable {
            // the user is not logged in to an iCloud account. We should have caught this
            // earlier, but if we didn't, the caller knows what to do
            return .notLoggedIn
        }
        
        return .cloud(cloudError)
    }
    
    static func ignoreUnknownItem(_ error: Error) throws(CloudKitResponseError) {
        if let cloudError = error as? CKError, cloudError.code == .unknownItem {
            return
        }
        
        throw wrapping(error)
    }
}
