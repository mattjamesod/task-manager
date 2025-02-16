//import Testing
//import KillerModels
//@testable import KillerData
//
//struct DatabaseTests {
//    let database = Database.inMemory()
//    
//    @Test func isertedTaskCanBeFetched() async throws {
//        let body = "I am a test"
//        await database.insert(KillerTask.self, \.body <- body)
//        let expectedTask = await database.fetch(KillerTask.self, query: .allActiveTasks).first
//        
//        #expect(expectedTask?.id == 1)
//        #expect(expectedTask?.body == body)
//        #expect(expectedTask?.completedAt == nil)
//        #expect(expectedTask?.deletedAt == nil)
//    }
//}
//
//// TODO: write other tests
