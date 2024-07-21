import Testing
@testable import KillerData

struct MutationHistoryTests {
    actor TestStateActor {
        var state: Int
        
        init(state: Int) {
            self.state = state
        }
        
        func update(newState: Int) {
            self.state = newState
        }
    }
    
    let stateActor: TestStateActor = .init(state: 5)
    let history: MutationHistory<TestStateActor> = .init()
    
    @Test func undoReturnsToInitialState() async {
        let operation = Bijection<TestStateActor>(
            goForward: { stateActor in
                await stateActor.update(newState: 10)
            },
            goBackward: { stateActor in
                await stateActor.update(newState: 5)
            }
        )
        
        await stateActor.update(newState: 10)
        
        await history.record(operation)
        
        await history.undo(stateActor)
        
        #expect(await stateActor.state == 5)
    }
}

