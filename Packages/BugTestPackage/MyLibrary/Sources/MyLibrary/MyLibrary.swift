
/// I believe this is the simplest possible repo.
///
/// The following changes allow compilation to succeed:
/// - Making `buggedFunc` a synchronous func
/// - Removing the custom error type from `buggedFunc`
/// - Changing the return type of `buggedFunc` to an `Optional<Model>` rather than an Array
/// - Removing the type param from `buggedFunc`
/// - Removing `callSite` (i.e. `buggedFunc` will compile if it is never called)

enum CustomError: Error { }

struct SpecificModel { }

func callSite() async {
    let _ = try? await buggedFunc(SpecificModel.self)
}

func buggedFunc<Model>(_ type: Model.Type) async throws(CustomError) -> [Model] {
    return []
}
