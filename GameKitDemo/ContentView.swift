//
//  ContentView.swift
//  GameKitDemo
//
//  Created by Itsuki on 2026/05/14.
//

import SwiftUI
import GameKit

struct ContentView: View {
    @State private var gameCenterManager = GameCenterManager()

    var body: some View {
        NavigationStack {
            Group {
                if self.gameCenterManager.isAuthenticated {
                    List {
                        Section("Achievements") {
                            ForEach(
                                gameCenterManager.achievementDescriptions,
                                id: \.identifier
                            ) { description in
                                let achievement: GKAchievement? = self
                                    .gameCenterManager.achievements.first(
                                        where: {
                                            $0.identifier
                                                == description.identifier
                                        })
                                HStack {
                                    Text(description.title)
                                        .frame(
                                            maxWidth: .infinity,
                                            alignment: .leading
                                        )

                                    if let achievement {
                                        CircularProgressView(
                                            progress: achievement
                                                .percentComplete
                                        )
                                    }
                                }
                                .contextMenu {
                                    if description
                                        .identifier == AchievementID.firstPlay,
                                        achievement?
                                            .isCompleted == false
                                    {
                                        Button(
                                            action: {
                                                self.gameCenterManager
                                                    .completeAchievement(
                                                        identifier: description
                                                            .identifier,
                                                        showCompletionBanner:
                                                            true
                                                    )
                                            },
                                            label: {
                                                Text("Complete!")
                                            }
                                        )

                                    } else {
                                        Button(
                                            action: {
                                                self.gameCenterManager
                                                    .reportAchievementProgress(
                                                        identifier: description
                                                            .identifier,
                                                        progress: (achievement?
                                                            .percentComplete
                                                            ?? 0) + 10,
                                                        showCompletionBanner:
                                                            true
                                                    )
                                            },
                                            label: {
                                                Text("Make Progress!")
                                            }
                                        )
                                    }
                                }
                            }
                        }

                        Section {
                            Button(
                                action: {
                                    self.gameCenterManager
                                        .resetAllAchievements()
                                },
                                label: {
                                    Text("Reset Achievements")
                                        .padding(.vertical, 8)
                                        .font(.headline)
                                }
                            )
                            .buttonSizing(.flexible)
                            .buttonStyle(.glassProminent)
                            .listRowBackground(Color.clear)
                            .listRowInsets(.horizontal, 0)
                        }

                        Section("Leaderboards") {
                            ForEach(
                                self.gameCenterManager.leaderboards,
                                id: \.baseLeaderboardID
                            ) { leaderboard in
                                let score = self.gameCenterManager
                                    .leaderboardScores[
                                        leaderboard.baseLeaderboardID
                                    ]
                                NavigationLink(
                                    destination: {
                                        LeaderboardView(
                                            leaderboard: leaderboard,
                                            score: score
                                        )
                                    },
                                    label: {
                                        VStack(alignment: .leading) {
                                            Text(
                                                leaderboard.title
                                                    ?? "Unknown Board"
                                            )
                                            if let score {
                                                Text(
                                                    "\(score.allScores.count) scores by \(score.totalPlayerCount) players."
                                                )
                                                .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                )
                                .contextMenu {
                                    Button(
                                        action: {
                                            self.gameCenterManager
                                                .submitLeaderboardScore(
                                                    leaderboard
                                                        .baseLeaderboardID,
                                                    score: (1...100)
                                                        .randomElement() ?? 1
                                                )
                                        },
                                        label: {
                                            Text("Submit Random Score!")
                                        }
                                    )

                                }
                            }
                        }
                    }
                } else {
                    Button(
                        action: {
                            gameCenterManager.initializeLocalPlayer()
                        },
                        label: {
                            Text("Sign In to Game Center")
                                .padding(.vertical, 8)
                                .font(.headline)
                        }
                    )
                    .buttonSizing(.flexible)
                    .buttonStyle(.glassProminent)
                    .padding()
                }
            }
            .navigationTitle("Game Center")
            .sheet(
                isPresented: $gameCenterManager.showController,
                content: {
                    if let controller = gameCenterManager.gameCenterController {
                        GameCenterAuthView(controller: controller)
                    }
                }
            )
        }

    }
}

private struct LeaderboardView: View {
    var leaderboard: GKLeaderboard
    var score: LeaderboardScore?
    var body: some View {
        List {
            Section("Top Scores") {
                if let score, score.allScores.count > 0 {
                    ForEach(score.allScoresSorted.enumerated(), id: \.offset) {
                        _,
                        entry in
                        Text(
                            "\(entry.formattedScore) by \(entry.player.displayName)"
                        )
                    }
                } else {
                    Text("No scores yet")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(leaderboard.title ?? "Unknown Board")
        .navigationBarTitleDisplayMode(.large)

    }
}

private struct CircularProgressView: View {
    let progress: Double
    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.8), style: .init(lineWidth: 4))
                .fill(.clear)

            Circle()
                .trim(from: 0.0, to: progress / 100)
                .stroke(.link, style: .init(lineWidth: 4))
                .fill(.clear)
        }
        .frame(width: 36)
        .overlay(content: {
            Text(
                "\(progress.formatted(.number.precision(.fractionLength(0))))%"
            )
            .fixedSize()
            .font(.caption.bold())
        })

    }
}

struct GameCenterAuthView: UIViewControllerRepresentable {
    var controller: UIViewController

    func makeUIViewController(context: Context) -> UIViewController {
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIViewController,
        context: Context
    ) {}
}

