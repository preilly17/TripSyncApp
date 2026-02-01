import SwiftUI

struct AddHotelSheetView: View {
    @ObservedObject var viewModel: HotelsListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var city = ""
    @State private var address = ""
    @State private var country = ""
    @State private var bookingUrl = ""
    @State private var checkInDate = Date()
    @State private var checkOutDate = Date()
    @State private var statusOption: HotelStatusOption = .confirmed

    @State private var isSubmitting = false
    @State private var alertInfo: AlertInfo?

    var body: some View {
        NavigationStack {
            Form {
                Section("Hotel Details") {
                    TextField("Name", text: $name)
                    TextField("City", text: $city)
                    TextField("Address", text: $address)
                    TextField("Country", text: $country)
                }

                Section("Dates") {
                    DatePicker(
                        "Check-in",
                        selection: $checkInDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    DatePicker(
                        "Check-out",
                        selection: $checkOutDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section("Booking") {
                    TextField("Booking URL", text: $bookingUrl)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }

                Section("Status") {
                    Picker("Status", selection: $statusOption) {
                        ForEach(HotelStatusOption.allCases) { option in
                            Text(option.title)
                                .tag(option)
                        }
                    }
                }
            }
            .navigationTitle("Add Hotel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await submit()
                        }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
            .alert(item: $alertInfo) { info in
                Alert(title: Text(info.title), message: Text(info.message))
            }
        }
        .task {
            await viewModel.loadCurrentUser()
        }
    }

    @MainActor
    private func submit() async {
        guard let resolvedName = requiredString(name, label: "name") else {
            return
        }

        guard let resolvedAddress = requiredString(address, label: "address") else {
            return
        }

        guard let resolvedCity = requiredString(city, label: "city") else {
            return
        }

        guard let resolvedCountry = requiredString(country, label: "country") else {
            return
        }

        if viewModel.currentUser == nil {
            await viewModel.loadCurrentUser()
        }

        guard let userId = viewModel.currentUser?.id else {
            alertInfo = AlertInfo(
                title: "Missing user information",
                message: "Please sign in again to add a hotel."
            )
            return
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let payload = AddHotelPayload(
            tripId: viewModel.tripIdentifier,
            userId: userId,
            hotelName: resolvedName,
            address: resolvedAddress,
            city: resolvedCity,
            country: resolvedCountry,
            checkInDate: formatter.string(from: checkInDate),
            checkOutDate: formatter.string(from: checkOutDate),
            bookingUrl: optionalString(bookingUrl),
            status: statusOption.apiValue,
            platform: "manual"
        )

        print("🏨 Create hotel payload:", payload)

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await viewModel.addHotel(payload: payload)
            dismiss()
        } catch let error as APIError {
            alertInfo = AlertInfo(
                title: "Unable to Add Hotel",
                message: error.errorDescription ?? "Something went wrong while adding the hotel."
            )
        } catch {
            alertInfo = AlertInfo(
                title: "Unable to Add Hotel",
                message: error.localizedDescription
            )
        }
    }

    private func requiredString(_ value: String, label: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            alertInfo = AlertInfo(title: "Missing \(label)", message: "Please enter a \(label).")
            return nil
        }
        return trimmed
    }

    private func optionalString(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private enum HotelStatusOption: String, CaseIterable, Identifiable {
    case confirmed
    case proposed
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .confirmed:
            return "Confirmed"
        case .proposed:
            return "Proposed"
        case .none:
            return "None"
        }
    }

    var apiValue: String? {
        switch self {
        case .none:
            return nil
        case .confirmed, .proposed:
            return rawValue
        }
    }
}

private struct AlertInfo: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

#Preview {
    AddHotelSheetView(viewModel: HotelsListViewModel(tripId: 1, hotelsAPI: nil))
}
