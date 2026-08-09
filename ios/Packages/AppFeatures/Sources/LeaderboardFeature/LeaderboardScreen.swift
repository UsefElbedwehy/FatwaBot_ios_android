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

                if !viewModel.boards.isEmpty {
                    // Custom awrad are deliberately unranked (owner decision,
                    // 2026-07). Saying so is the difference between a rule and
                    // a user quietly concluding their effort doesn't register.
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Color(hexToken: tokens.accent))
                        Text("leaderboard.scoring_notice")
                            .font(.footnote)
                            .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
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
    /// Derived from the prayer-times location. Not editable: the app already
    /// knows where the user is, and asking them to type it invites typos that
    /// silently fragment a city board — "Riyadh", "riyadh" and "الرياض" become
    /// three leaderboards nobody is competing on. Client request, 2026-08-09.
    let suggestedRegion: LeaderboardRegion
    let onJoin: (Bool, String?) -> Void

    @State private var publishName = false
    @Environment(\.dismiss) private var dismiss

    private var isCityScope: Bool { board.scope == "city" }
    private var isCountryScope: Bool { board.scope == "country" }
    /// A country board has nothing to ask the user for — it is derived — so the
    /// only thing that can block it is not knowing the country at all.
    private var missingCountry: Bool { isCountryScope && suggestedRegion.countryCode == nil }
    /// A city board is equally underivable without a city.
    private var missingCity: Bool { isCityScope && suggestedRegion.city == nil }
    private var missingRegion: Bool { missingCountry || missingCity }

    /// "مصر" rather than "EG". The code is an implementation detail of the API;
    /// showing it to a user is showing them our plumbing.
    private var countryName: String? {
        suggestedRegion.countryCode.flatMap {
            Locale.current.localizedString(forRegionCode: $0) ?? $0
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Toggle("leaderboard.publish_name", isOn: $publishName)
                if isCityScope, let city = suggestedRegion.city {
                    LabeledContent("leaderboard.city", value: city)
                }
                if isCountryScope, let countryName {
                    LabeledContent("leaderboard.country", value: countryName)
                }
                if missingRegion {
                    // Previously this sheet let the user tap Join and the server
                    // answered 400 country_required — an error they had no way
                    // to act on. Say what is wrong and what fixes it instead.
                    Text("leaderboard.region_unavailable")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(Text("leaderboard.join_sheet_title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("leaderboard.confirm_join") {
                        // nil for both scopes now: the view model derives the
                        // city from the same location, so passing a copy from
                        // here would just be a second source of truth.
                        onJoin(publishName, nil)
                    }
                    // Blocked only when the region genuinely cannot be derived.
                    // There is nothing for the user to fix by typing, so the
                    // message below explains it instead of a disabled field.
                    .disabled(missingRegion)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
        }
    }
}
