import SwiftUI
import CoreText

extension Team {
    static let palette = ["Ocean", "Amber", "Mint", "Rose", "Violet"]
    var background: Color {
        switch color {
        case "Amber": return Color(red: 0.97, green: 0.66, blue: 0.20)
        case "Mint": return Color(red: 0.36, green: 0.84, blue: 0.65)
        case "Rose": return Color(red: 0.91, green: 0.35, blue: 0.48)
        case "Violet": return Color(red: 0.40, green: 0.28, blue: 0.75)
        default: return Color(red: 0.08, green: 0.32, blue: 0.70)
        }
    }
    var foreground: Color { ["Amber", "Mint"].contains(color) ? Color.black : Color.white }
}
struct Scoreboard: View {
    @EnvironmentObject var store: MatchStore
    let match: Match
    var showGames: Bool { [.gamesCelebration, .awaitingConfirmation, .finished].contains(match.phase) }
    var status: String {
        switch match.phase {
        case .points: return match.score.tieBreak ? "TIE-BREAK" : "DOUBLE TAP +1 · HOLD −1"
        case .pointCelebration: return "GAME"
        case .gamesCelebration: return match.score.winner == nil ? "GAMES" : "MATCH WON"
        case .awaitingConfirmation: return "TAP TO START NEXT GAME"
        case .finished: return "\(match.teams[match.score.winner ?? 0].name.uppercased()) WINS"
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            Text(status).font(.system(size: 11, weight: .bold, design: .rounded)).tracking(1.5).padding(8)
            HStack(spacing: 2) { ForEach(0..<2) { team in panel(team) } }
            HStack {
                ForEach(0..<2) { team in
                    Text("\(match.teams[team].name)  ·  \(match.setsWon[team]) sets  ·  \(match.score.games[team]) games")
                        .frame(maxWidth: .infinity)
                }
            }.font(.caption2).padding(8)
            if match.phase == .awaitingConfirmation {
                Button("Next game", systemImage: "play.fill") { store.command("confirm", matchID: match.id) }.padding(6)
            }
            if let message = store.connectionMessage { Text(message).font(.caption2).foregroundStyle(.orange) }
        }
        .background(Color.black).foregroundStyle(.white)
    }
    private func panel(_ team: Int) -> some View {
        GeometryReader { _ in
            TimelineView(.animation(minimumInterval: 0.4)) { timeline in
                let blink = [.pointCelebration, .gamesCelebration].contains(match.phase)
                let dim = blink && Int(timeline.date.timeIntervalSince1970 * 2.5) % 2 == 0
                VStack(spacing: 0) {
                    Text(match.teams[team].name.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .lineLimit(1).padding(.top, 6)
                        .fixedSize(horizontal: false, vertical: true)
                    GeometryReader { _ in
                        FittedScore(value: value(team))
                            .padding(4)
                            .opacity(dim ? 0.25 : 1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(match.teams[team].background).foregroundStyle(match.teams[team].foreground)
                .contentShape(Rectangle())
                .gesture(LongPressGesture(minimumDuration: store.snapshot.preferences.holdDuration)
                    .exclusively(before: TapGesture(count: 2))
                    .onEnded { gesture in
                        switch gesture {
                        case .first: store.command("remove", team: team, matchID: match.id)
                        case .second: store.command("add", team: team, matchID: match.id)
                        }
                    })
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(match.teams[team].name), \(value(team))")
                .accessibilityAction(named: "Add point") { store.command("add", team: team, matchID: match.id) }
                .accessibilityAction(named: "Remove point") { store.command("remove", team: team, matchID: match.id) }
            }
        }
    }
    private func value(_ team: Int) -> String {
        if showGames {
            // A completed set is shown during its celebration instead of the reset 0–0.
            let games = match.score.games == [0, 0] ? (match.score.sets.last ?? match.score.games) : match.score.games
            return String(games[team])
        }
        return match.pointLabel(team)
    }
}

/// Fit the actual glyph outlines, excluding the font's invisible line spacing.
/// Uniform scaling preserves the digits' proportions and keeps AD / tie-breaks in bounds.
private struct FittedScore: View {
    let value: String

    private var outline: CGPath {
        let system = CTFontCreateUIFontForLanguage(.system, 100, nil)!
        let descriptor = CTFontDescriptorCreateCopyWithAttributes(
            CTFontCopyFontDescriptor(system),
            [kCTFontTraitsAttribute: [kCTFontWeightTrait: 0.62]] as CFDictionary
        )
        let font = CTFontCreateWithFontDescriptor(descriptor, 100, nil)
        let text = NSAttributedString(string: value, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font
        ])
        let line = CTLineCreateWithAttributedString(text)
        let result = CGMutablePath()
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
            for index in 0..<count {
                if let glyph = CTFontCreatePathForGlyph(font, glyphs[index], nil) {
                    result.addPath(glyph, transform: CGAffineTransform(
                        translationX: positions[index].x, y: positions[index].y
                    ))
                }
            }
        }
        return result
    }

    var body: some View {
        let glyphs = outline
        Canvas { context, size in
            let bounds = glyphs.boundingBoxOfPath
            guard bounds.width > 0, bounds.height > 0 else { return }
            let scale = min(size.width / bounds.width, size.height / bounds.height)
            let x = (size.width - bounds.width * scale) / 2
            let y = (size.height - bounds.height * scale) / 2
            context.translateBy(x: x, y: y + bounds.height * scale)
            context.scaleBy(x: scale, y: -scale)
            context.translateBy(x: -bounds.minX, y: -bounds.minY)
            context.fill(Path(glyphs), with: .foreground)
        }
        .accessibilityHidden(true)
    }
}
