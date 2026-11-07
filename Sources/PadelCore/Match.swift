import Foundation

public enum DeuceRule: String, Codable, CaseIterable, Sendable { case golden, advantage }
public struct Preferences: Codable, Equatable, Sendable {
    public var pointBlink: Double = 5
    public var gamesBlink: Double = 5
    public var holdDuration: Double = 2
    public var confirmNextGame = false
    public init() {}
}
public struct Team: Codable, Equatable, Sendable {
    public var name: String
    public var color: String
    public init(name: String, color: String) { self.name = name; self.color = color }
}
public struct Score: Codable, Equatable, Sendable {
    public var points = [0, 0]
    public var games = [0, 0]
    public var sets: [[Int]] = []
    public var winner: Int?
    public var tieBreak = false
    public init() {}
}
public enum MatchPhase: String, Codable, Sendable { case points, pointCelebration, gamesCelebration, awaitingConfirmation, finished, stopped = "stoped" }
public struct Match: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var started = Date()
    public var ended: Date?
    public var teams: [Team]
    public var rule: DeuceRule
    public var score = Score()
    public var history: [Int] = []
    public var phase: MatchPhase = .points
    public var phaseStarted = Date()
    public var winningPoints = [0, 0]
    public var winningTieBreak = false
    public init(teams: [Team], rule: DeuceRule) { self.teams = teams; self.rule = rule }
    public var isOver: Bool { phase == .finished || phase == .stopped }
    public mutating func stop(now: Date = Date()) {
        guard !isOver else { return }
        phase = .stopped; ended = now; phaseStarted = now
    }
    public var setsWon: [Int] { [0, 1].map { team in score.sets.filter { $0[team] > $0[1-team] }.count } }
    public func pointLabel(_ team: Int) -> String {
        let p = phase == .pointCelebration ? winningPoints : score.points
        if phase == .pointCelebration ? winningTieBreak : score.tieBreak { return String(p[team]) }
        if p[team] >= 3 && p[1-team] >= 3 {
            return p[team] > p[1-team] ? "AD" : "40"
        }
        return ["0", "15", "30", "40"][min(p[team], 3)]
    }
    public mutating func addPoint(to team: Int, now: Date = Date()) {
        guard (0...1).contains(team), phase == .points, score.winner == nil else { return }
        history.append(team)
        if apply(team) {
            phase = .pointCelebration; phaseStarted = now
        }
    }
    // Replaying the point log makes a correction restore games, tie-breaks and sets too.
    public mutating func removePoint(from team: Int, now: Date = Date()) {
        guard phase != .stopped, let index = history.lastIndex(of: team) else { return }
        history.remove(at: index)
        score = Score()
        for point in history { _ = apply(point) }
        phase = score.winner == nil ? .points : .finished
        ended = score.winner == nil ? nil : now
        phaseStarted = now
    }
    private mutating func apply(_ team: Int) -> Bool {
        guard score.winner == nil else { return false }
        score.points[team] += 1
        let p = score.points
        let won = score.tieBreak ? (p[team] >= 7 && p[team] - p[1-team] >= 2) :
            (p[team] >= 4 && (rule == .golden || p[team] - p[1-team] >= 2))
        guard won else { return false }
        winningPoints = p
        winningTieBreak = score.tieBreak
        score.points = [0, 0]
        score.games[team] += 1
        if score.tieBreak || (score.games[team] >= 6 && score.games[team] - score.games[1-team] >= 2) {
            score.sets.append(score.games)
            score.games = [0, 0]; score.tieBreak = false
            if setsWon[team] == 2 { score.winner = team }
        } else if score.games == [6, 6] { score.tieBreak = true }
        return true
    }
    public mutating func advance(now: Date = Date(), preferences: Preferences) {
        if phase == .pointCelebration && now.timeIntervalSince(phaseStarted) >= preferences.pointBlink {
            phase = .gamesCelebration
            phaseStarted = phaseStarted.addingTimeInterval(preferences.pointBlink)
        }
        if phase == .gamesCelebration && now.timeIntervalSince(phaseStarted) >= preferences.gamesBlink {
            if score.winner != nil { phase = .finished; ended = now }
            else { phase = preferences.confirmNextGame ? .awaitingConfirmation : .points }
            phaseStarted = now
        }
    }
    public mutating func confirm(now: Date = Date()) {
        guard phase == .awaitingConfirmation else { return }
        phase = .points; phaseStarted = now
    }
}
