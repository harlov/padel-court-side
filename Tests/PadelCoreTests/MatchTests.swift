import XCTest
@testable import PadelCore
final class MatchTests: XCTestCase {
    func match(_ rule: DeuceRule = .golden) -> Match { Match(teams: [.init(name: "A", color: "blue"), .init(name: "B", color: "orange")], rule: rule) }
    func point(_ m: inout Match, _ team: Int) {
        m.addPoint(to: team)
        var prefs = Preferences(); prefs.pointBlink = 0; prefs.gamesBlink = 0
        m.advance(preferences: prefs)
    }
    func game(_ m: inout Match, _ team: Int) { for _ in 0..<4 { point(&m, team) } }
    func testGoldenDeuce() {
        var m = match()
        for _ in 0..<3 { point(&m, 0); point(&m, 1) }
        point(&m, 0)
        XCTAssertEqual(m.score.games, [1, 0])
    }
    func testAdvantages() {
        var m = match(.advantage)
        for _ in 0..<3 { point(&m, 0); point(&m, 1) }
        point(&m, 0); XCTAssertEqual(m.pointLabel(0), "AD")
        point(&m, 1); XCTAssertEqual(m.pointLabel(0), "40")
        point(&m, 0); point(&m, 0)
        XCTAssertEqual(m.score.games, [1, 0])
    }
    func testTieBreakAndMatch() {
        var m = match()
        for _ in 0..<6 { game(&m, 0); game(&m, 1) }
        XCTAssertTrue(m.score.tieBreak)
        for _ in 0..<6 { point(&m, 0); point(&m, 1) }
        point(&m, 0); XCTAssertTrue(m.score.tieBreak)
        point(&m, 0); XCTAssertEqual(m.score.sets, [[7, 6]])
        for _ in 0..<6 { game(&m, 0) }
        XCTAssertEqual(m.score.winner, 0)
        XCTAssertEqual(m.phase, .finished)
        m.removePoint(from: 0)
        XCTAssertNil(m.score.winner)
        XCTAssertEqual(m.score.games, [5, 0])
        XCTAssertEqual(m.score.points, [3, 0])
    }
    func testTieBreakCelebrationKeepsNumericPoints() {
        var m = match()
        for _ in 0..<6 { game(&m, 0); game(&m, 1) }
        for _ in 0..<6 { point(&m, 0) }
        m.addPoint(to: 0)
        XCTAssertEqual(m.pointLabel(0), "7")
        XCTAssertEqual(m.pointLabel(1), "0")
        XCTAssertFalse(m.score.tieBreak)
    }
    func testTransitionsAndConfirmation() {
        var m = match(); let start = Date()
        for _ in 0..<4 { m.addPoint(to: 0, now: start) }
        XCTAssertEqual(m.phase, .pointCelebration)
        m.addPoint(to: 1); XCTAssertEqual(m.history.count, 4)
        var prefs = Preferences(); prefs.confirmNextGame = true
        m.advance(now: start.addingTimeInterval(5), preferences: prefs)
        XCTAssertEqual(m.phase, .gamesCelebration)
        m.advance(now: start.addingTimeInterval(10), preferences: prefs)
        XCTAssertEqual(m.phase, .awaitingConfirmation)
        m.confirm(); XCTAssertEqual(m.phase, .points)
    }
    func testStoppedMatchPreservesScoreAndRejectsFurtherScoring() throws {
        var m = match()
        game(&m, 0); point(&m, 1)
        let score = m.score
        let history = m.history
        let end = Date()
        m.stop(now: end)
        XCTAssertEqual(m.phase.rawValue, "stoped")
        XCTAssertTrue(m.isOver)
        XCTAssertEqual(m.ended, end)
        m.addPoint(to: 0); m.removePoint(from: 0)
        m.confirm(); m.advance(now: end.addingTimeInterval(30), preferences: Preferences())
        m.stop(now: end.addingTimeInterval(60))
        XCTAssertEqual(m.score, score)
        XCTAssertEqual(m.history, history)
        XCTAssertEqual(m.ended, end)
        XCTAssertEqual(m.phase, .stopped)
        XCTAssertEqual(try JSONDecoder().decode(Match.self, from: JSONEncoder().encode(m)), m)
    }
    func testStopDuringGameCelebration() {
        var m = match()
        for _ in 0..<4 { m.addPoint(to: 0) }
        m.stop()
        m.advance(now: Date().addingTimeInterval(60), preferences: Preferences())
        XCTAssertEqual(m.phase, .stopped)
        XCTAssertEqual(m.score.games, [1, 0])
        XCTAssertNil(m.score.winner)
    }
    func testCorrectionAndCodable() throws {
        var m = match(); point(&m, 0); point(&m, 1); point(&m, 0)
        m.removePoint(from: 1); XCTAssertEqual(m.score.points, [2, 0])
        m.removePoint(from: 1); XCTAssertEqual(m.score.points, [2, 0])
        XCTAssertEqual(try JSONDecoder().decode(Match.self, from: JSONEncoder().encode(m)), m)
    }
}
