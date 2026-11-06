import SwiftUI
import UIKit

@main
struct PadelApp: App {
    @StateObject private var store = MatchStore()
    var body: some Scene { WindowGroup { HomeView().environmentObject(store).preferredColorScheme(.dark) } }
}
struct HomeView: View {
    @EnvironmentObject var store: MatchStore
    @State private var newMatch = false
    @State private var settings = false
    @State private var scoring = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("COURT SIDE").font(.caption.weight(.bold)).tracking(4).foregroundStyle(.mint)
                        Text("Every point\ncounts.").font(.system(size: 48, weight: .heavy, design: .rounded))
                        Text("Your matches. One tap closer.").foregroundStyle(.secondary)
                    }.padding(.top, 24)
                    if let match = store.active {
                        Button { scoring = true } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("MATCH IN PROGRESS", systemImage: "circle.fill").font(.caption.bold()).foregroundStyle(.mint)
                                Text("\(match.teams[0].name) vs \(match.teams[1].name)").font(.title3.bold()).foregroundStyle(.white)
                                Text("Return to court →").foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(22).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
                        }
                    } else {
                        Button { newMatch = true } label: {
                            HStack { Image(systemName: "plus"); Text("Start a new match"); Spacer(); Image(systemName: "arrow.up.right") }
                                .font(.headline).padding(22).background(.mint, in: RoundedRectangle(cornerRadius: 20)).foregroundStyle(.black)
                        }
                    }
                    Text("MATCH HISTORY").font(.caption.bold()).tracking(2).foregroundStyle(.secondary)
                    let finished = store.snapshot.matches.filter { $0.phase == .finished }
                    if finished.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: "tennis.racket").font(.largeTitle).foregroundStyle(.mint)
                            Text("Your first match awaits.").font(.headline)
                            Text("Finished matches and set scores will appear here.").font(.subheadline).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(24).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 20))
                    }
                    ForEach(finished) { match in
                        NavigationLink { MatchDetail(match: match) } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(match.started.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                                ForEach(0..<2) { team in
                                    HStack {
                                        Circle().fill(match.teams[team].background).frame(width: 10, height: 10)
                                        Text(match.teams[team].name).fontWeight(match.score.winner == team ? .bold : .regular)
                                        Spacer()
                                        ForEach(Array(match.score.sets.enumerated()), id: \.offset) { _, set in Text("\(set[team])").monospacedDigit() }
                                    }
                                }
                            }.padding(20).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                        }.buttonStyle(.plain)
                    }
                }.padding(24)
            }
            .background(Color(red: 0.035, green: 0.055, blue: 0.075))
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Settings", systemImage: "slider.horizontal.3") { settings = true } } }
            .sheet(isPresented: $newMatch) { NewMatchView { scoring = true } }
            .sheet(isPresented: $settings) { SettingsView() }
            .fullScreenCover(isPresented: $scoring) { MatchScreen() }
        }
    }
}
struct NewMatchView: View {
    @EnvironmentObject var store: MatchStore
    @Environment(\.dismiss) var dismiss
    @State private var rule: DeuceRule = .golden
    @State private var left = "Team One"
    @State private var right = "Team Two"
    @State private var leftColor = "Ocean"
    @State private var rightColor = "Amber"
    let onStart: () -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section("Scoring") {
                    Picker("Deuce rule", selection: $rule) { Text("Golden point").tag(DeuceRule.golden); Text("Advantages").tag(DeuceRule.advantage) }
                    Text(rule == .golden ? "At 40–40, the next point wins the game." : "At 40–40, win two consecutive points.").font(.caption).foregroundStyle(.secondary)
                    Text("Best of 3 sets · tie-break to 7 at 6–6 · win by 2").font(.caption)
                }
                Section("Left side") { TextField("Team name", text: $left); colorPicker("Color", selection: $leftColor) }
                Section("Right side") { TextField("Team name", text: $right); colorPicker("Color", selection: $rightColor) }
                Section {
                    HStack(spacing: 4) {
                        ForEach(0..<2) { index in
                            let team = index == 0 ? Team(name: left, color: leftColor) : Team(name: right, color: rightColor)
                            Text(team.name).font(.headline).frame(maxWidth: .infinity).padding(22).background(team.background).foregroundStyle(team.foreground)
                        }
                    }.clipShape(RoundedRectangle(cornerRadius: 12))
                    Text("Double tap a side to add a point. Hold to remove that team’s most recent point. Rotate iPhone to landscape to score.").font(.caption).foregroundStyle(.secondary)
                }
                Button("Start match") {
                    store.start(teams: [.init(name: name(left, fallback: "Team One"), color: leftColor), .init(name: name(right, fallback: "Team Two"), color: rightColor)], rule: rule)
                    dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onStart() }
                }.font(.headline).disabled(leftColor == rightColor)
                if leftColor == rightColor { Text("Choose different colors for the two teams.").foregroundStyle(.orange) }
            }.navigationTitle("New match").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
    private func name(_ value: String, fallback: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : String(value.prefix(24)) }
    private func colorPicker(_ title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) { ForEach(Team.palette, id: \.self) { Text($0).tag($0) } }
    }
}
struct SettingsView: View {
    @EnvironmentObject var store: MatchStore
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Game transitions") {
                    Stepper("Point score blink: \(Int(store.snapshot.preferences.pointBlink)) sec", value: preference(\.pointBlink), in: 1...15)
                    Stepper("Games score blink: \(Int(store.snapshot.preferences.gamesBlink)) sec", value: preference(\.gamesBlink), in: 1...15)
                    Toggle("Confirm before next game", isOn: preference(\.confirmNextGame))
                }
                Section("Gestures") {
                    Stepper("Hold to correct: \(store.snapshot.preferences.holdDuration, specifier: "%.1f") sec", value: preference(\.holdDuration), in: 0.5...5, step: 0.5)
                    Text("Double tap adds one point. A hold removes the selected team’s last point and recalculates the match.").font(.caption)
                }
            }.navigationTitle("Settings").toolbar { Button("Done") { dismiss() } }
        }
    }
    private func preference<T>(_ keyPath: WritableKeyPath<Preferences, T>) -> Binding<T> {
        Binding(get: { store.snapshot.preferences[keyPath: keyPath] }, set: { value in
            var preferences = store.snapshot.preferences; preferences[keyPath: keyPath] = value; store.settings(preferences)
        })
    }
}
struct MatchScreen: View {
    @EnvironmentObject var store: MatchStore
    @Environment(\.dismiss) var dismiss
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                if let match = store.snapshot.matches.first {
                    if geometry.size.width > geometry.size.height {
                        Scoreboard(match: match).padding(.top, 32)
                    } else {
                        VStack(spacing: 18) {
                            Image(systemName: "iphone.gen3.radiowaves.left.and.right").font(.system(size: 52)).foregroundStyle(.mint)
                            Text("Turn to landscape").font(.title.bold())
                            Text("Give every point the big screen.").foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                Button { dismiss() } label: { Label("Matches", systemImage: "xmark.circle.fill").font(.caption).padding(8) }.tint(.white)
            }.background(.black)
        }.onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}
struct MatchDetail: View {
    let match: Match
    var body: some View {
        List {
            Section(match.started.formatted(date: .abbreviated, time: .shortened)) {
                Text("\(match.teams[match.score.winner ?? 0].name) won").font(.title2.bold())
                ForEach(Array(match.score.sets.enumerated()), id: \.offset) { index, set in
                    LabeledContent("Set \(index + 1)", value: "\(set[0]) – \(set[1])")
                }
                LabeledContent("Rule", value: match.rule == .golden ? "Golden point" : "Advantages")
            }
        }.navigationTitle("Match result")
    }
}
