//
//  GameCenterManager.swift
//  GameKitDemo
//
//  Created by Itsuki on 2026/05/14.
//

import GameKit
import SwiftUI

enum AchievementID {
    static let firstPlay = "itsuki.enjoy.GameKitDemo.firstPlay"
    static let tenPlays = "itsuki.enjoy.GameKitDemo.tenPlay"

    static let allAchievements: [String] = [
        firstPlay, tenPlays,
    ]
}

enum LeaderboardID {
    static let highScore = "itsuki.enjoy.GameKitDemo.highScore"

    static let allLeaderboards: [String] = [
        highScore
    ]
}


struct LeaderboardScore {
    var localPlayerScore: GKLeaderboard.Entry?
    // The scores this method loads that match the playerScope, timeScope, and range parameters, including the local player’s score if it exists.
    var allScores: [GKLeaderboard.Entry]
    var totalPlayerCount: Int

    var allScoresSorted: [GKLeaderboard.Entry] {
        return self.allScores.sorted(by: { first, second in
            first.rank < second.rank
        })
    }
}


// MARK: - GameCenterManager Implementation
@Observable
final class GameCenterManager {

    private(set) var achievements: [GKAchievement] = []
    private(set) var achievementDescriptions: [GKAchievementDescription] = []

    private(set) var leaderboards: [GKLeaderboard] = []
    private(set) var leaderboardScores: [String: LeaderboardScore] = [:]

    var showController: Bool = false {
        didSet {
            if !showController {
                self.gameCenterController = nil
            }
        }
    }

    var gameCenterController: UIViewController? {
        didSet {
            if self.gameCenterController != nil {
                self.showController = true
            }
        }
    }

    var error: Error? {
        didSet {
            if let error {
                print(error)
            }
        }
    }

    var isAuthenticated: Bool = false
    var isUnderage: Bool = false
    var isMultiplayerGamingRestricted: Bool = false
    var isPersonalizedCommunicationRestricted: Bool = false

    private var localPlayer: GKLocalPlayer {
        // make sure to always return one that reflect the latest status
        return GKLocalPlayer.local
    }

    init() {
        self.refreshLocalPlayerStatus()
        self.initializeLocalPlayer()
        if self.isAuthenticated, !self.isUnderage {
            self.loadAchievements()
            self.loadAchievementDetails()
            self.loadLeaderboards()
        }
    }

    func initializeLocalPlayer() {
        // to listen for changes: GKPlayerAuthenticationDidChangeNotificationName
        localPlayer.authenticateHandler = { viewController, error in
            self.refreshLocalPlayerStatus()

            if let viewController = viewController {
                self.gameCenterController = viewController
                // Present the view controller so the player can sign in.
                return
            }

            if error != nil {
                // Player is not available
                // Disable Game Center in the game.
                self.error = error
                return
            }

            if self.isAuthenticated, !self.isUnderage {
                self.loadAchievements()
                self.loadAchievementDetails()
                self.loadLeaderboards()
            }
        }
    }

    private func refreshLocalPlayerStatus() {
        self.isAuthenticated = localPlayer.isAuthenticated
        self.isUnderage = localPlayer.isUnderage
        self.isMultiplayerGamingRestricted =
            localPlayer.isMultiplayerGamingRestricted
        self.isPersonalizedCommunicationRestricted =
            localPlayer.isPersonalizedCommunicationRestricted
    }
}

// MARK: - Achievements
extension GameCenterManager {

    func loadAchievements() {
        Task {
            do {
                // Loads the achievements that you previously reported the player making progress toward.
                var achievements = try await GKAchievement.loadAchievements()
                let nonExisting = AchievementID.allAchievements.filter({
                    !achievements.map(\.identifier).contains($0)
                })
                achievements.append(
                    contentsOf: nonExisting.map({
                        GKAchievement(identifier: $0)
                    })
                )
                self.achievements = achievements
            } catch (let error) {
                self.error = error
            }
        }
    }

    func loadAchievementDetails() {
        Task {
            do {
                self.achievementDescriptions =
                    try await GKAchievementDescription
                    .loadAchievementDescriptions()
            } catch (let error) {
                self.error = error
            }
        }
    }

    func loadImageForAchievement(identifier: String) async -> Image? {
        guard
            let achievement = self.achievementDescriptions.first(where: {
                $0.identifier == identifier
            })
        else {
            return nil
        }

        guard let uiImage = try? await achievement.loadImage() else {
            return nil
        }

        return Image(uiImage: uiImage)
    }

    // showsCompletionBanner
    // - A Boolean value that indicates whether GameKit displays a banner when the player completes the achievement.
    //   Set to false to disable system default banner and display our own UI
    func completeAchievement(identifier: String, showCompletionBanner: Bool) {
        self.reportAchievementProgress(
            identifier: identifier,
            progress: 100,
            showCompletionBanner: showCompletionBanner
        )
    }

    // When reporting a percentage greater than 0 and less than 100, the dashboard shows the achievement as in-progress.
    // When you report that the player completes the achievement 100%, the dashboard shows the image for the achievement, and Game Center adds it to the player’s completed achievements.
    func reportAchievementProgress(
        identifier: String,
        progress: Double,
        showCompletionBanner: Bool
    ) {
        guard (0...100).contains(progress) else {
            return
        }

        let achievement =
            self.achievements.first(where: {
                $0.identifier == identifier
            }) ?? .init(identifier: identifier)

        achievement.percentComplete = progress
        achievement.showsCompletionBanner = showCompletionBanner
        Task {
            do {
                try await GKAchievement.report([achievement])
                print("finish reporting")
                if let index = self.achievements.firstIndex(where: {
                    $0.identifier == identifier
                }) {
                    self.achievements[index] = achievement
                } else {
                    self.achievements.append(achievement)
                }
            } catch (let error) {
                self.error = error
            }
        }
    }

    func resetAllAchievements() {
        Task {
            do {
                try await GKAchievement.resetAchievements()
                self.loadAchievements()
            } catch (let error) {
                self.error = error
            }
        }
    }
}

// MARK: - Leaderboards
extension GameCenterManager {

    func loadLeaderboards(
        _ leaderboardIDs: [String] = LeaderboardID.allLeaderboards
    ) {
        Task {
            do {
                // Loads leaderboards for the specified leaderboard IDs that Game Center uses.
                // If leaderboardIDs is nil, this loads all classic and recurring leaderboards for this game.
                let leaderboards = try await GKLeaderboard.loadLeaderboards(
                    IDs: leaderboardIDs
                )
                for board in leaderboards {
                    if let index = self.leaderboards.firstIndex(where: {
                        $0.baseLeaderboardID == board.baseLeaderboardID
                    }) {
                        self.leaderboards[index] = board
                    } else {
                        self.leaderboards.append(board)
                    }
                    self.loadScoresForLeaderboard(board.baseLeaderboardID)
                }
            } catch (let error) {
                self.error = error
            }
        }
    }

    func submitLeaderboardScore(_ identifier: String, score: Int) {
        Task {
            do {
                // Loads leaderboards for the specified leaderboard IDs that Game Center uses.
                // If leaderboardIDs is nil, this loads all classic and recurring leaderboards for this game.
                try await GKLeaderboard.submitScore(
                    score,
                    context: 0,
                    player: self.localPlayer,
                    leaderboardIDs: [identifier]
                )
                // to refresh the score
                self.loadScoresForLeaderboard(identifier)
            } catch (let error) {
                self.error = error
            }
        }
    }

    func loadScoresForLeaderboard(_ identifier: String) {
        guard
            let leaderboard = self.leaderboards.first(where: {
                $0.baseLeaderboardID == identifier
            })
        else { return }

        Task {
            do {
                // Loads leaderboards for the specified leaderboard IDs that Game Center uses.
                // If leaderboardIDs is nil, this loads all classic and recurring leaderboards for this game.
                let scores = try await leaderboard.loadEntries(
                    for: GKLeaderboard.PlayerScope.global,
                    timeScope: GKLeaderboard.TimeScope.allTime,
                    range: NSMakeRange(1, 100)
                )
                self.leaderboardScores[identifier] = .init(
                    localPlayerScore: scores.0,
                    allScores: scores.1,
                    totalPlayerCount: scores.2
                )
            } catch (let error) {
                self.error = error
            }
        }
    }
}
