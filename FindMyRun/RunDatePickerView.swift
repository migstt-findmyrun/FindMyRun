//
//  RunDatePickerView.swift
//  FindMyRun
//

import SwiftUI

enum DateFlexibility: String, CaseIterable {
    case exact = "Exact dates"
    case one = "± 1 day"
    case two = "± 2 days"
    case three = "± 3 days"
    case week = "± 1 week"

    var days: Int {
        switch self {
        case .exact: return 0
        case .one: return 1
        case .two: return 2
        case .three: return 3
        case .week: return 7
        }
    }
}

struct RunDatePickerView: View {
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    @Binding var flexibility: DateFlexibility
    let onNext: () -> Void
    let onReset: () -> Void

    @State private var displayMonth: Date = Calendar.current.startOfDay(for: Date())

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday
        return cal
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Month header
            monthHeader

            // Day headers
            dayHeaders

            // Calendar grid
            calendarGrid

            // Flexibility pills
            flexibilityRow
        }
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Text(displayMonth, format: .dateTime.month(.wide).year())
                .font(.headline)
                .fontDesign(.rounded)

            Spacer()

            HStack(spacing: 12) {
                Button {
                    displayMonth = calendar.date(byAdding: .month, value: -1, to: displayMonth) ?? displayMonth
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(canGoPrev ? .primary : .tertiary)
                }
                .disabled(!canGoPrev)

                Button {
                    displayMonth = calendar.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    private var canGoPrev: Bool {
        let thisMonth = calendar.dateComponents([.year, .month], from: Date())
        let shown = calendar.dateComponents([.year, .month], from: displayMonth)
        if let t = thisMonth.month, let s = shown.month,
           let ty = thisMonth.year, let sy = shown.year {
            return sy > ty || (sy == ty && s > t)
        }
        return false
    }

    // MARK: - Day Headers

    private var dayHeaders: some View {
        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        return HStack(spacing: 0) {
            ForEach(letters.indices, id: \.self) { i in
                Text(letters[i])
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let days = daysInMonth()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
            ForEach(days.indices, id: \.self) { i in
                if let day = days[i] {
                    DayCell(
                        date: day,
                        today: calendar.isDateInToday(day),
                        isPast: day < calendar.startOfDay(for: Date()),
                        isStart: startDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false,
                        isEnd: endDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false,
                        inRange: isInRange(day),
                        onTap: { handleDayTap(day) }
                    )
                } else {
                    Color.clear.frame(height: 36)
                }
            }
        }
    }

    private func daysInMonth() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayMonth)) else {
            return []
        }

        // Offset for Monday start
        let weekday = calendar.component(.weekday, from: firstDay)
        // weekday: Sun=1, Mon=2, ...
        let offset = (weekday - 2 + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        // Pad to full grid
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private func isInRange(_ date: Date) -> Bool {
        guard let s = startDate, let e = endDate else { return false }
        return date >= s && date <= e
    }

    private func handleDayTap(_ date: Date) {
        if startDate == nil || (startDate != nil && endDate != nil) {
            startDate = calendar.startOfDay(for: date)
            endDate = nil
        } else if let s = startDate {
            let tapped = calendar.startOfDay(for: date)
            if tapped < s {
                startDate = tapped
                endDate = nil
            } else {
                endDate = tapped
            }
        }
    }

    // MARK: - Flexibility Pills

    private var flexibilityRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DateFlexibility.allCases, id: \.self) { f in
                    Button {
                        flexibility = f
                    } label: {
                        Text(f.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)
                            .foregroundStyle(flexibility == f ? .primary : .secondary)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 14)
                            .background {
                                if flexibility == f {
                                    Capsule().stroke(.primary, lineWidth: 1.5)
                                } else {
                                    Capsule().fill(Color(.systemGray5))
                                }
                            }
                    }
                }
            }
        }
    }

    // MARK: - Action Row

    private var actionRow: some View {
        HStack {
            Button("Reset", action: onReset)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: onNext) {
                Text("Search")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 24)
                    .background(.orange, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Day Cell

private struct DayCell: View {
    let date: Date
    let today: Bool
    let isPast: Bool
    let isStart: Bool
    let isEnd: Bool
    let inRange: Bool
    let onTap: () -> Void

    private var day: Int {
        Calendar.current.component(.day, from: date)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Range background
                if inRange && !isStart && !isEnd {
                    Rectangle()
                        .fill(.orange.opacity(0.15))
                        .frame(height: 36)
                }

                // Start/end caps
                if isStart || isEnd {
                    Circle()
                        .fill(.orange)
                        .frame(width: 34, height: 34)
                }

                Text("\(day)")
                    .font(.subheadline)
                    .fontWeight(isPast ? .regular : .bold)
                    .fontDesign(.rounded)
                    .foregroundStyle(
                        isStart || isEnd ? Color.white :
                        isPast ? Color(.tertiaryLabel) : Color.primary
                    )
            }
            .frame(height: 36)
        }
        .disabled(isPast)
    }
}
