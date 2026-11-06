import SwiftUI
@main
struct PadelWatchApp: App {
    @StateObject private var store = MatchStore()
    var body: some Scene {
        WindowGroup {
            Group {
                if let match = store.active ?? store.snapshot.matches.first {
                    Scoreboard(match: match)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "tennis.racket").font(.largeTitle).foregroundStyle(.mint)
                        Text("Ready for court").font(.headline)
                        Text("Start a match on your iPhone. Your score will appear here.").font(.caption).multilineTextAlignment(.center).foregroundStyle(.secondary)
                    }.padding()
                }
            }.environmentObject(store)
        }
    }
}
