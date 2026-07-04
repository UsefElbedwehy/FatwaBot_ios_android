import DesignSystemKit
import PrayerKit
import SwiftUI

public struct PrayerScreen: View {
    @State private var viewModel: PrayerViewModel
    @State private var dayOffset = 0
    @Environment(\.colorScheme) private var colorScheme

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
                    withAnimation(.snappy) { dayOffset -= 1 }
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .disabled(dayOffset <= -7)
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
                Spacer()
                Button {
                    withAnimation(.snappy) { dayOffset += 1 }
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .disabled(dayOffset >= 7)
            }
            if let location = viewModel.location {
                Label(location.name, systemImage: location.isManual ? "building.2" : "location.fill")
                    .font(.caption)
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
            }
        }
    }

    private var dayTitle: String {
        let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date())!
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private func timesCard(for day: PrayerDay) -> some View {
        VStack(spacing: 0) {
            ForEach(day.ordered, id: \.name) { entry in
                let isNext = dayOffset == 0 && viewModel.nextPrayer?.next == entry.name
                HStack {
                    Text(entry.name.localizedTitle)
                        .font(isNext ? .body.weight(.semibold) : .body)
                    Spacer()
                    Text(entry.time.formatted(date: .omitted, time: .shortened))
                        .font(isNext ? .body.weight(.semibold) : .body)
                        .monospacedDigit()
                }
                .foregroundStyle(Color(hexToken: isNext ? tokens.primary : tokens.onSurface))
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

    var body: some View {
        List(ManualCity.bundled) { city in
            Button {
                onSelect(city, String(localized: String.LocalizationValue(city.nameKey)))
            } label: {
                Text(String(localized: String.LocalizationValue(city.nameKey)))
            }
        }
        .navigationTitle(Text("prayer.pick_city"))
    }
}
