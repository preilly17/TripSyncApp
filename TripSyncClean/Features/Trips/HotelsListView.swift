import SwiftUI

struct HotelsListView: View {
    @ObservedObject var viewModel: HotelsListViewModel
    @State private var selectedHotel: Hotel?

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Loading hotels")
                    .frame(maxWidth: .infinity, minHeight: 120)
            case .empty:
                ContentUnavailableView(
                    "No hotels yet",
                    systemImage: "bed.double",
                    description: Text("Add your stay details to keep the trip organized.")
                )
                .frame(maxWidth: .infinity, minHeight: 160)
            case .loaded(let hotels):
                LazyVStack(spacing: 12) {
                    ForEach(hotels) { hotel in
                        HotelRowCard(hotel: hotel) {
                            selectedHotel = hotel
                        }
                    }
                }
            case .error(let message):
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text("Unable to load hotels")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 160)
            }
        }
        .task {
            if case .loading = viewModel.state {
                await viewModel.load()
            }
        }
        .navigationDestination(item: $selectedHotel) { hotel in
            HotelDetailView(hotel: hotel)
        }
    }
}

private struct HotelRowCard: View {
    let hotel: Hotel
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(hotel.displayTitle)
                                .font(.headline)

                            Text(hotel.locationText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let statusText {
                            Text(statusText)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.accentColor.opacity(0.15))
                                )
                        }
                    }

                    Text(hotel.dateRangeText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if let bookingLink {
                Link("View booking", destination: bookingLink)
                    .font(.subheadline)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var statusText: String? {
        guard let status = hotel.status?.trimmingCharacters(in: .whitespacesAndNewlines),
              !status.isEmpty else {
            return nil
        }
        return status
    }

    private var bookingLink: URL? {
        guard let bookingUrl = hotel.bookingUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !bookingUrl.isEmpty else {
            return nil
        }
        return URL(string: bookingUrl)
    }
}

struct HotelDetailView: View {
    let hotel: Hotel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(hotel.displayTitle)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(hotel.locationText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                detailRow(label: "Dates", value: hotel.dateRangeText)

                if let status = hotel.status, !status.isEmpty {
                    detailRow(label: "Status", value: status)
                }

                if let address = hotel.address, !address.isEmpty {
                    detailRow(label: "Address", value: address)
                }

                if let bookingUrl = hotel.bookingUrl,
                   let url = URL(string: bookingUrl) {
                    Link("Open booking", destination: url)
                        .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .navigationTitle("Hotel Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    HotelsListView(viewModel: HotelsListViewModel(tripId: 1, hotelsAPI: nil))
        .padding()
}
