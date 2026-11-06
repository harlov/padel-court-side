import Foundation
import SwiftUI
import WatchConnectivity

struct Snapshot: Codable {
    var matches: [Match] = []
    var preferences = Preferences()
    var processed: Set<UUID> = []
    var revision = 0
}
struct ScoreCommand: Codable {
    var id = UUID()
    var matchID: UUID
    var action: String
    var team: Int
}
final class MatchStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published var snapshot: Snapshot
    @Published var connectionMessage: String?
    private let key = "padel.snapshot.v1"
    private var timer: Timer?
    var active: Match? { snapshot.matches.first { $0.phase != .finished } }
    override init() {
        snapshot = UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) } ?? Snapshot()
        super.init()
        if WCSession.isSupported() { WCSession.default.delegate = self; WCSession.default.activate() }
        #if os(iOS)
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.tick() }
        #else
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let match = self.active,
                  [.pointCelebration, .gamesCelebration].contains(match.phase) else { return }
            self.requestSnapshot()
        }
        #endif
    }
    func start(teams: [Team], rule: DeuceRule) {
        guard active == nil else { return }
        snapshot.matches.insert(Match(teams: teams, rule: rule), at: 0); persist()
    }
    func settings(_ preferences: Preferences) { snapshot.preferences = preferences; persist() }
    func command(_ action: String, team: Int = 0, matchID: UUID? = nil) {
        guard let id = matchID ?? active?.id else { return }
        let command = ScoreCommand(matchID: id, action: action, team: team)
        #if os(watchOS)
        guard WCSession.default.isReachable else {
            connectionMessage = "Connect to your iPhone to score."; return
        }
        guard let data = try? JSONEncoder().encode(command) else { return }
        WCSession.default.sendMessage(["command": data], replyHandler: { reply in
            DispatchQueue.main.async { self.receive(reply); self.connectionMessage = nil }
        }, errorHandler: { _ in
            DispatchQueue.main.async { self.connectionMessage = "Couldn’t confirm point. Check iPhone before retrying." }
        })
        #else
        apply(command)
        #endif
    }
    private func apply(_ command: ScoreCommand) {
        guard !snapshot.processed.contains(command.id),
              let index = snapshot.matches.firstIndex(where: { $0.id == command.matchID }) else { return }
        snapshot.processed.insert(command.id)
        switch command.action {
        case "add": snapshot.matches[index].addPoint(to: command.team)
        case "remove": snapshot.matches[index].removePoint(from: command.team)
        case "confirm": snapshot.matches[index].confirm()
        default: return
        }
        persist()
    }
    private func tick() {
        guard let index = snapshot.matches.firstIndex(where: { $0.phase != .finished }) else { return }
        let before = snapshot.matches[index]
        snapshot.matches[index].advance(preferences: snapshot.preferences)
        if before != snapshot.matches[index] { persist() }
    }
    private func persist() {
        snapshot.revision += 1
        if let data = try? JSONEncoder().encode(snapshot) { UserDefaults.standard.set(data, forKey: key) }
        publish()
    }
    private func payload() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(snapshot) else { return [:] }
        return ["snapshot": data]
    }
    private func publish() {
        #if os(iOS)
        guard WCSession.default.activationState == .activated else { return }
        do { try WCSession.default.updateApplicationContext(payload()) }
        catch { connectionMessage = "Watch sync will resume when connected." }
        #endif
    }
    private func receive(_ message: [String: Any]) {
        #if os(watchOS)
        if let data = message["snapshot"] as? Data,
           let incoming = try? JSONDecoder().decode(Snapshot.self, from: data), incoming.revision >= snapshot.revision {
            snapshot = incoming; UserDefaults.standard.set(data, forKey: key)
        }
        #else
        tick()
        if let data = message["command"] as? Data, let command = try? JSONDecoder().decode(ScoreCommand.self, from: data) { apply(command) }
        #endif
    }
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.receive(session.receivedApplicationContext)
            self.publish()
            self.requestSnapshot()
        }
    }
    func sessionReachabilityDidChange(_ session: WCSession) { DispatchQueue.main.async { self.requestSnapshot() } }
    private func requestSnapshot() {
        #if os(watchOS)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["request": true], replyHandler: { reply in
                DispatchQueue.main.async { self.receive(reply) }
            }, errorHandler: { _ in })
        }
        #endif
    }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async { self.receive(applicationContext) }
    }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async { self.receive(message); replyHandler(self.payload()) }
    }
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}
