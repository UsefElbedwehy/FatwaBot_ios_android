import DesignSystemKit
import SwiftUI

public struct LeaderboardScreen: View {
    @State private var viewModel: LeaderboardViewModel
    @State private var joinTarget: LeaderboardBoard?
    @Environment(\.colorScheme) private var colorScheme

    public init(viewModel: LeaderboardViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var tokens: ColorTokens {
        let base = DesignTokens.bundledDefault
        return colorScheme == .dark ? base.dark : base.light
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let error = viewModel.error {
                    HStack(spacing: 10) {
                        Image(systemName: "wifi.exclamationmark").foregroundStyle(Color(hexToken: tokens.accent))
                        Text(error).font(.footnote).foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                    }
                    .brandCard(tokens)
                }

                ForEach(viewModel.boards) { board in
                    BoardCard(
                        board: board,
                        tokens: tokens,
                        onJoin: { joinTarget = board },
                        onLeave: { Task { await viewModel.leave(key: board.key) } }
                    )
                }

                if !viewModel.isLoading && viewModel.boards.isEmpty && viewModel.error == nil {
                    BrandEmptyState(systemImage: "trophy", messageKey: "leaderboard.empty_state", tokens: tokens)
                }
            }
            .padding(20)
        }
        .brandScreenBackground(tokens)
        .overlay {
            if viewModel.isLoading && viewModel.boards.isEmpty {
                ProgressView().tint(Color(hexToken: tokens.primary))
            }
        }
        .navigationTitle(Text("leaderboard.title"))
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .sheet(item: $joinTarget) { board in
            JoinSheet(board: board, suggestedRegion: viewModel.suggestedRegion) { publishName, city in
                joinTarget = nil
                Task { await viewModel.join(key: board.key, publishName: publishName, city: city) }
            }
        }
    }
}

private struct BoardCard: View {
    let board: LeaderboardBoard
    let tokens: ColorTokens
    let onJoin: () -> Void
    let onLeave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(board.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color(hexToken: tokens.onSurface))
                    Text("\(board.scope) · \(board.period)")
                        .font(.caption)
                        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                }
                Spacer(minLength: 8)
                if let myRank = board.myRank {
                    Text("leaderboard.my_rank \(myRank)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color(hexToken: tokens.primaryContainer), in: Capsule())
                        .foregroundStyle(Color(hexToken: tokens.primary))
                }
            }
            .accessibilityElement(children: .combine)

            if board.joined {
                VStack(spacing: 0) {
                    ForEach(Array(board.entries.enumerated()), id: \.element.rank) { index, entry in
                        EntryRow(entry: entry, isMe: entry.rank == board.myRank, tokens: tokens)
                        if index < board.entries.count - 1 {
                            Divider().opacity(0.35)
                        }
                    }
                }
                Button(role: .destructive, action: onLeave) {
                    Text("leaderboard.leave")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color(hexToken: tokens.primary))
                .controlSize(.regular)
            } else {
                Button(action: onJoin) {
                    Label("leaderboard.join", systemImage: "person.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hexToken: tokens.primary))
                .controlSize(.large)
            }
        }
        .brandCard(tokens, padding: 18)
    }
}

private struct EntryRow: View {
    let entry: LeaderboardEntry
    let isMe: Bool
    let tokens: ColorTokens

    var body: some View {
        HStack(spacing: 12) {
            RankMedal(rank: entry.rank, tokens: tokens)
                .accessibilityHidden(true)
            Text(entry.displayName)
                .fontWeight(isMe ? .bold : .regular)
                .foregroundStyle(Color(hexToken: isMe ? tokens.primary : tokens.onSurface))
            Spacer(minLength: 8)
            Text("\(Int(entry.score))")
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(
            isMe ? Color(hexToken: tokens.primary).opacity(0.08) : Color.clear,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("leaderboard.rank_a11y \(entry.rank) \(entry.displayName)"))
        .accessibilityValue(Text("\(Int(entry.score))"))
    }
}

private struct JoinSheet: View {
    let board: LeaderboardBoard
    /// Prefill from the prayer-times location. The user can still overwrite it —
    /// the app's idea of "your city" and the one someone wants to compete in are
    /// not always the same (travel, a nearby larger city).
    let suggestedRegion: LeaderboardRegion
    let onJoin: (Bool, String?) -> Void

    @State private var publishName = false
    @State private var city = ""
    @State private var didPrefill = false
    @Environment(\.dismiss) private var dismiss

    private var isCityScope: Bool { board.scope == "city" }
    private var isCountryScope: Bool { board.scope == "country" }
    /// A country board has nothing to ask the user for — it is derived — so the
    /// only thing that can block it is not knowing the country at all.
    private var missingCountry: Bool { isCountryScope && suggestedRegion.countryCode == nil }

    var body: some View {
        NavigationStack {
            Form {
                Toggle("leaderboard.publish_name", isOn: $publishName)
                if isCityScope {
                    TextField("leaderboard.city_placeholder", text: $city)
                }
                if isCountryScope, let code = suggestedRegion.countryCode {
                    LabeledContent("leaderboard.country", value: code)
                }
                if missingCountry {
                    // Previously this sheet let the user tap Join and the server
                    // answered 400 country_required — an error they had no way
                    // to act on. Say what is wrong and what fixes it instead.
                    Text("leaderboard.country_unavailable")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                guard !didPrefill else { return }
                didPrefill = true
                if isCityScope, let suggested = suggestedRegion.city { city = suggested }
            }
            .navigationTitle(Text("leaderboard.join_sheet_title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("leaderboard.confirm_join") {
                        onJoin(publishName, isCityScope ? city : nil)
                    }
                    .disabled(
                        (isCityScope && city.trimmingCharacters(in: .whitespaces).isEmpty) || missingCountry
                    )
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
        }
    }
}
