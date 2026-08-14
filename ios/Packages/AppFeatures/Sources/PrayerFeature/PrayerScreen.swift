import DesignSystemKit
import PrayerKit
import SwiftUI

public struct PrayerScreen: View {
    @State private var viewModel: PrayerViewModel
    @State private var dayOffset = 0
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(viewModel: PrayerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        Group {
            switch viewModel.status {
            case .needsLocation:
                CityPickerView { city, name in
                    viewModel.select(city: city, displayName: name)
                }
            case .ready:
                content
            }
        }
        .task { await viewModel.start() }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                if let day = viewModel.day(offset: dayOffset) {
                    timesCard(for: day)
                } else {
                    ProgressView().padding(.top, 60)
                }
            }
            .padding()
        }
        .background(Color(hexToken: tokens.surface))
    }

    private var tokens: ColorTokens {
        let base = DesignTokens.bundledDefault
        return colorScheme == .dark ? base.dark : base.light
    }

    private var header: some View {
        VStack(spacing: 6) {
            HStack {
                Button {
                    setDayOffset(dayOffset - 1)
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .disabled(dayOffset <= -7)
                .accessibilityLabel(Text("prayer.previous_day"))
                Spacer()
                VStack(spacing: 2) {
                    if dayOffset == 0, let hijri = viewModel.hijri {
                        Text("\(hijri.monthName) \(hijri.day)، \(String(hijri.year)) هـ")
                            .font(.headline)
                    }
                    Text(dayTitle)
                        .font(.subheadline)
                        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                }
                .accessibilityElement(children: .combine)
                Spacer()
                Button {
                    setDayOffset(dayOffset + 1)
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .disabled(dayOffset >= 7)
                .accessibilityLabel(Text("prayer.next_day"))
            }
            if let location = viewModel.location {
                Label(location.name, systemImage: location.isManual ? "building.2" : "location.fill")
                    .font(.caption)
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
            }
        }
    }

    private func setDayOffset(_ newValue: Int) {
        if reduceMotion {
            dayOffset = newValue
        } else {
            withAnimation(.snappy) { dayOffset = newValue }
        }
    }

    private var dayTitle: String {
        var calendar = Calendar.current
        calendar.timeZone = viewModel.displayTimeZone
        let date = calendar.date(byAdding: .day, value: dayOffset, to: Date())!
        return date.formatted(
            Date.FormatStyle(timeZone: viewModel.displayTimeZone).weekday(.wide).day().month(.wide)
        )
    }

    private func timesCard(for day: PrayerDay) -> some View {
        VStack(spacing: 0) {
            ForEach(day.ordered, id: \.name) { entry in
                let isNext = dayOffset == 0 && viewModel.nextPrayer?.next == entry.name
                HStack {
                    Text(entry.name.localizedTitle)
                        .font(isNext ? .body.weight(.semibold) : .body)
                    Spacer()
                    Text(entry.time.formatted(
                        Date.FormatStyle(date: .omitted, time: .shortened, timeZone: viewModel.displayTimeZone)
                    ))
                        .font(isNext ? .body.weight(.semibold) : .body)
                        .monospacedDigit()
                }
                .foregroundStyle(Color(hexToken: isNext ? tokens.primary : tokens.onSurface))
                .accessibilityElement(children: .combine)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(
                    isNext ? Color(hexToken: tokens.primaryContainer) : .clear,
                    in: RoundedRectangle(cornerRadius: 12)
                )
                if entry.name != .isha {
                    Divider().opacity(0.4)
                }
            }
        }
        .padding(8)
        .background(Color(hexToken: tokens.surfaceElevated), in: RoundedRectangle(cornerRadius: 18))
    }
}

extension PrayerName {
    /// Bundled fallback titles; string packs override at the app layer.
    public var localizedTitle: LocalizedStringKey {
        switch self {
        case .fajr: "prayer.fajr"
        case .sunrise: "prayer.sunrise"
        case .dhuhr: "prayer.dhuhr"
        case .asr: "prayer.asr"
        case .maghrib: "prayer.maghrib"
        case .isha: "prayer.isha"
        }
    }
}

struct CityPickerView: View {
    let onSelect: (ManualCity, String) -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var tokens: ColorTokens {
        let base = DesignTokens.bundledDefault
        return colorScheme == .dark ? base.dark : base.light
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BrandSectionHeader("prayer.pick_city", systemImage: "location.magnifyingglass", tokens: tokens)

                LazyVStack(spacing: 12) {
                    ForEach(ManualCity.bundled) { city in
                        cityRow(city)
                    }
                }
            }
            .padding(20)
        }
        .brandScreenBackground(tokens)
        .navigationTitle(Text("prayer.pick_city"))
    }

    private func cityRow(_ city: ManualCity) -> some View {
        let name = String(localized: String.LocalizationValue(city.nameKey))
        return Button {
            onSelect(city, name)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color(hexToken: tokens.primaryContainer))
                    Image(systemName: "mappin.and.ellipse")
                        .font(.title3)
                        .foregroundStyle(Color(hexToken: tokens.primary))
                }
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)

                Text(name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(hexToken: tokens.onSurface))

                Spacer(minLength: 8)

                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                    .accessibilityHidden(true)
            }
            .brandCard(tokens)
        }
        .buttonStyle(.plain)
    }
}
