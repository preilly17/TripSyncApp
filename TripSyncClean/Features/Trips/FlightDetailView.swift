import SwiftUI

struct FlightDetailView: View {
    let flight: Flight

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerView

                FlightDetailSection(title: "Schedule") {
                    FlightDetailRow(label: "Departure airport", value: airportText(flight.departureAirport))
                    FlightDetailRow(label: "Departure time", value: formattedDateTime(flight.departureDate))
                    FlightDetailRow(label: "Arrival airport", value: airportText(flight.arrivalAirport))
                    FlightDetailRow(label: "Arrival time", value: formattedDateTime(flight.arrivalDate))
                }

                FlightDetailSection(title: "Details") {
                    FlightDetailRow(label: "Duration", value: detailText(flight.duration))
                    FlightDetailRow(label: "Stops", value: stopsText)

                    if let seatClassText {
                        FlightDetailRow(label: "Seat class", value: seatClassText)
                    }

                    if let aircraftText {
                        FlightDetailRow(label: "Aircraft", value: aircraftText)
                    }

                    if let platformText {
                        FlightDetailRow(label: "Platform", value: platformText)
                    }
                }

                FlightDetailSection(title: "Cost") {
                    FlightDetailRow(label: costLabel, value: costValue)
                }

                if let proposerDisplay {
                    FlightDetailSection(title: "Proposed by") {
                        FlightDetailRow(label: "Traveler", value: proposerDisplay)
                    }
                }

                if let bookingLink {
                    Link("Open booking", destination: bookingLink)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(16)
        }
        .navigationTitle("Flight Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(flight.displayTitle)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(flight.routeText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let statusText = statusText {
                    Text(statusText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.accentColor.opacity(0.15))
                        )
                }
            }
        }
    }

    private var statusText: String? {
        guard let status = flight.status?.trimmingCharacters(in: .whitespacesAndNewlines),
              !status.isEmpty else {
            return nil
        }
        return status
    }

    private var seatClassText: String? {
        guard let seatClass = flight.seatClass?.trimmingCharacters(in: .whitespacesAndNewlines),
              !seatClass.isEmpty else {
            return nil
        }
        return seatClass
    }

    private var aircraftText: String? {
        guard let aircraft = flight.aircraft?.trimmingCharacters(in: .whitespacesAndNewlines),
              !aircraft.isEmpty else {
            return nil
        }
        return aircraft
    }

    private var platformText: String? {
        let platform = flight.platform?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let bookingSource = flight.bookingSource?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !platform.isEmpty && !bookingSource.isEmpty {
            if platform.lowercased() == bookingSource.lowercased() {
                return platform
            }
            return "\(platform) • \(bookingSource)"
        }

        if !platform.isEmpty {
            return platform
        }

        if !bookingSource.isEmpty {
            return bookingSource
        }

        return nil
    }

    private var bookingLink: URL? {
        guard let raw = flight.bookingUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              let url = URL(string: raw) else {
            return nil
        }
        return url
    }

    private var proposerDisplay: String? {
        guard let proposer = flight.proposer?.trimmingCharacters(in: .whitespacesAndNewlines),
              !proposer.isEmpty else {
            return nil
        }

        if proposer.range(of: "^\\d+$", options: .regularExpression) != nil {
            return nil
        }

        if proposer.range(of: "^[0-9a-fA-F-]{32,}$", options: .regularExpression) != nil {
            return nil
        }

        return proposer
    }

    private var stopsText: String {
        guard let stops = flight.stops else {
            return "TBD"
        }
        if stops == 0 {
            return "Nonstop"
        }
        if stops == 1 {
            return "1 stop"
        }
        return "\(stops) stops"
    }

    private var costLabel: String {
        if flight.pointsCost != nil {
            return "Points"
        }
        return "Price"
    }

    private var costValue: String {
        if let pointsCost = flight.pointsCost {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            let formatted = formatter.string(from: NSNumber(value: pointsCost)) ?? "\(pointsCost)"
            return formatted
        }

        if let price = flight.price, !price.isEmpty {
            if let currency = flight.currency, !currency.isEmpty {
                return "\(price) \(currency)"
            }
            return price
        }

        return "TBD"
    }

    private func formattedDateTime(_ date: Date?) -> String {
        if let formatted = FlightDateFormatter.dateTimeString(from: date) {
            return formatted
        }
        return "TBD"
    }

    private func airportText(_ value: String?) -> String {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return "TBD"
        }
        return trimmed
    }

    private func detailText(_ value: String?) -> String {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return "TBD"
        }
        return trimmed
    }
}

private struct FlightDetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct FlightDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.leading)
            Spacer()
        }
    }
}
