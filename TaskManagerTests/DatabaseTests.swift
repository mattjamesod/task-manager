import Testing
import SQLite
@testable import TaskManager

struct DatabaseTests {
    let database = try! Database(schema: .testing, connection: try! SQLite.Connection())
    
    @Test func isertedTaskCanBeFetched() async throws {
        let body = "I am a test"
        await database.insert(KillerTask.self, setting: \.body, to: body)
        let expectedTask = await database.fetch(KillerTask.self, query: .allActiveItems).first
        
        #expect(expectedTask?.body == body)
        #expect(expectedTask?.isCompleted == false)
        #expect(expectedTask?.isDeleted == false)
    }

}
