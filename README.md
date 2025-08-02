# Prototype "Killer"

Apologies if the codename comes off as crass - it's meant to invoke the word kilelr as in the phrase "killer app" or "killer feature".

Killer is a prototype for a task manager app, native to iOS and macOS. It supports indefinitely indenting subtasks, multiple windows, and a flexible layout.

## Architecture

I built this prototype to get comforatble with Swift's async/await system. It is compiled against Swift 6 with the Swift 6 language mode.

### Event-driven Design

The core of the app is the SQLite database in the KillerData package. The principal design decision for Killer is that this local database is always and forever the source of truth for all dynamic data in the app.

To facilitate this, any edit to the database triggers an event in a custom event system, implemented with AsyncStreams. Any subscriber that cares about this data only updates in response to such events. This is how CloudKit is updated, and it's how the UI updates in response to CloudKit events. Even in SwiftUI views, view state is rarely updated directly - the database is updated, and then the view responds to the resulting event by updating it's own state.

This architecture has many advantages for a SWiftUI project in particular, as views depending on the same state no longer rely on their own cached versions. Usually the SwiftUI developer would have to manually sync these views. For example, the macOS version of Killer can open multiple windows looking at different task list views. Those views will all update when the user interacts with the others, and this behaviour comes for free - the task list views only know what tasks they want to show and what tasks they don't.

One particularly interesting challenge this presented was SwiftUI TextField views.

### Flexible Layout

Killer implements its own sidebar and stack views, similar to SwiftUI's native navigation views. Killer switches between these views using ViewThatFits.
