
public class ModelRegistry: @unchecked Sendable {
    private var registrations: [String: any DataBacked.Type]
    
    init() {
        self.registrations = [:]
    }
    
    public func register(_ type: any DataBacked.Type, as key: String) {
        self.registrations[key] = type
    }
    
    func fetch(_ key: String) -> (any DataBacked.Type)? {
        registrations[key]
    }
}
