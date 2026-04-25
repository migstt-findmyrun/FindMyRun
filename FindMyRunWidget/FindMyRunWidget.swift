//
//  FindMyRunWidget.swift
//  FindMyRunWidget
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct NextRunEntry: TimelineEntry {
    let date: Date
    let nextRun: WidgetRun?
}

// MARK: - Provider

struct NextRunProvider: TimelineProvider {

    func placeholder(in context: Context) -> NextRunEntry {
        NextRunEntry(date: .now, nextRun: previewRun)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextRunEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextRunEntry>) -> Void) {
        let entry = loadEntry()
        let refresh = entry.nextRun.map { max($0.occursAt, Date().addingTimeInterval(3600)) }
            ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func loadEntry() -> NextRunEntry {
        let next = SharedRunStore.load()
            .filter { $0.occursAt > Date() }
            .sorted { $0.occursAt < $1.occursAt }
            .first
        return NextRunEntry(date: .now, nextRun: next)
    }
}

// MARK: - Polyline Decoder

private struct DecodedRoute {
    /// Points normalised independently: x ∈ [0,1] for longitude, y ∈ [0,1] for latitude (flipped).
    let points: [CGPoint]
    /// True width/height ratio accounting for latitude-based mercator compression.
    let aspectRatio: CGFloat
}

private func decodePolyline(_ encoded: String) -> DecodedRoute? {
    let bytes = Array(encoded.utf8)
    var coords: [(lat: Double, lng: Double)] = []
    var i = 0, lat = 0, lng = 0
    while i < bytes.count {
        var result = 0, shift = 0, byte: Int
        repeat {
            byte = Int(bytes[i]) - 63; i += 1
            result |= (byte & 0x1F) << shift; shift += 5
        } while byte >= 0x20
        lat += (result & 1) != 0 ? ~(result >> 1) : result >> 1
        result = 0; shift = 0
        repeat {
            byte = Int(bytes[i]) - 63; i += 1
            result |= (byte & 0x1F) << shift; shift += 5
        } while byte >= 0x20
        lng += (result & 1) != 0 ? ~(result >> 1) : result >> 1
        coords.append((Double(lat) / 1e5, Double(lng) / 1e5))
    }
    guard coords.count > 1 else { return nil }

    let lats = coords.map(\.lat), lngs = coords.map(\.lng)
    let minLat = lats.min()!, maxLat = lats.max()!
    let minLng = lngs.min()!, maxLng = lngs.max()!
    let latRange = maxLat - minLat
    let lngRange = maxLng - minLng
    guard latRange > 0, lngRange > 0 else { return nil }

    // Mercator correction: a degree of longitude is cos(lat) times shorter than a degree of latitude
    let centerLat = (minLat + maxLat) / 2.0
    let mercatorCorrection = cos(centerLat * .pi / 180.0)
    let aspectRatio = CGFloat((lngRange * mercatorCorrection) / latRange)

    let points = coords.map { p in
        CGPoint(
            x: (p.lng - minLng) / lngRange,
            y: 1.0 - (p.lat - minLat) / latRange
        )
    }
    return DecodedRoute(points: points, aspectRatio: aspectRatio)
}

// MARK: - Route Shape View

private struct RouteShapeView: View {
    let route: DecodedRoute

    var body: some View {
        GeometryReader { geo in
            Path { path in
                guard let first = route.points.first else { return }
                path.move(to: CGPoint(x: first.x * geo.size.width,
                                      y: first.y * geo.size.height))
                for p in route.points.dropFirst() {
                    path.addLine(to: CGPoint(x: p.x * geo.size.width,
                                             y: p.y * geo.size.height))
                }
            }
            .stroke(.red.opacity(0.8),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
        .aspectRatio(route.aspectRatio, contentMode: .fit)
    }
}

// MARK: - Empty State

private struct EmptyWidgetView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "bookmark")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("No saved runs")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Small Widget

private struct SmallWidgetView: View {
    let run: WidgetRun

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "figure.run.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption2)
                Text("NEXT RUN")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
            }

            Spacer()

            Text(run.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text(run.clubName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.top, 2)

            Divider().padding(.vertical, 6)

            Text(run.occursAt, style: .relative)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.red)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Medium Widget

private struct MediumWidgetView: View {
    let run: WidgetRun

    private var decodedRoute: DecodedRoute? {
        guard let polyline = run.polyline else { return nil }
        return decodePolyline(polyline)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {

            // — Left: route map —
            if let route = decodedRoute {
                RouteShapeView(route: route)
                    .frame(maxHeight: .infinity)
                    .padding(14)

                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 0.5)
                    .padding(.vertical, 10)
            }

            // — Right: run details —
            VStack(alignment: .leading, spacing: 0) {
                // Date badge
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Text(run.occursAt, format: .dateTime.weekday(.abbreviated))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                        Text(run.occursAt, format: .dateTime.day())
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(run.occursAt, format: .dateTime.month(.abbreviated))
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(width: 38, height: 38)
                    .background(.red.gradient, in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(run.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)

                        if let city = run.clubCity {
                            Text("\(run.clubName) · \(city)")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else {
                            Text(run.clubName)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.leading, 8)
                }

                Spacer()

                // Meta
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Label(run.occursAt.formatted(date: .omitted, time: .shortened),
                              systemImage: "clock")
                        if let km = run.distanceKm {
                            Label(km, systemImage: "figure.run")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    HStack(spacing: 3) {
                        Image(systemName: "timer")
                        Text(run.occursAt, style: .relative)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Entry View

struct FindMyRunWidgetEntryView: View {
    var entry: NextRunEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let run = entry.nextRun {
                switch family {
                case .systemSmall:
                    SmallWidgetView(run: run)
                default:
                    MediumWidgetView(run: run)
                }
            } else {
                EmptyWidgetView()
            }
        }
        .widgetURL(entry.nextRun.flatMap { URL(string: "findmyrun://findmyrun.app/run/\($0.id)") })
    }
}

// MARK: - Widget

struct FindMyRunWidget: Widget {
    let kind: String = "FindMyRunWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextRunProvider()) { entry in
            FindMyRunWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Next Run")
        .description("Shows your next saved run with a live countdown.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview helpers

private let previewRun = WidgetRun(
    id: "1",
    title: "Thursday Evening Run",
    clubName: "Portland Runners Toronto",
    clubCity: "Toronto",
    occursAt: Calendar.current.date(byAdding: .day, value: 2, to: .now)!,
    address: "Portland St & King St W",
    distanceKm: "5.0 km",
    polyline: "wnh~Hzr~iNuCzEwAzBcBvCwBnDeCtDiBlC}@tA}@rAyAlBmBxCmBxCsBxC{@pA}@tA_BvBgClDkC~DqB~CmBzCqB|CyApBkBxCiAbBcA~AaAdBcArBaAdBcAlBqBvD_B~CUb@GJKRKPc@t@IPKPMNKPGJ"
)

#Preview(as: .systemMedium) {
    FindMyRunWidget()
} timeline: {
    NextRunEntry(date: .now, nextRun: previewRun)
    NextRunEntry(date: .now, nextRun: nil)
}

#Preview(as: .systemSmall) {
    FindMyRunWidget()
} timeline: {
    NextRunEntry(date: .now, nextRun: previewRun)
    NextRunEntry(date: .now, nextRun: nil)
}
