import SwiftUI

struct AddFlightSheetView: View {
    @ObservedObject var viewModel: FlightsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var airline = ""
    @State private var airlineCode = ""
    @State private var flightNumber = ""
    @State private var departureAirport = ""
    @State private var departureCode = ""
    @State private var departureTime = ""
    @State private var arrivalAirport = ""
    @State private var arrivalCode = ""
    @State private var arrivalTime = ""
    @State private var pointsCost = ""

    @State private var pointsCostError: String?
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Flight Details") {
                    TextField("Airline", text: $airline)
                    TextField("Airline Code", text: $airlineCode)
                    TextField("Flight Number", text: $flightNumber)
                    TextField("Departure Airport", text: $departureAirport)
                    TextField("Departure Code", text: $departureCode)
                        .textInputAutocapitalization(.characters)
                    TextField("Arrival Airport", text: $arrivalAirport)
                    TextField("Arrival Code", text: $arrivalCode)
                        .textInputAutocapitalization(.characters)
                    TextField("Departure Time (ISO 8601)", text: $departureTime)
                    TextField("Arrival Time (ISO 8601)", text: $arrivalTime)
                }

                Section("Points") {
                    TextField("Points Cost (optional)", text: $pointsCost)
                        .keyboardType(.numberPad)
                    if let pointsCostError {
                        Text(pointsCostError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Flight")
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
        }
    }

    @MainActor
    private func submit() async {
        pointsCostError = nil
        errorMessage = nil

        guard let resolvedAirline = requiredString(airline, label: "airline"),
              let resolvedFlightNumber = requiredString(flightNumber, label: "flight number"),
              let resolvedAirlineCode = requiredString(airlineCode, label: "airline code"),
              let resolvedDepartureAirport = requiredString(departureAirport, label: "departure airport"),
              let resolvedDepartureCode = requiredString(departureCode, label: "departure code"),
              let resolvedArrivalAirport = requiredString(arrivalAirport, label: "arrival airport"),
              let resolvedArrivalCode = requiredString(arrivalCode, label: "arrival code") else {
            return
        }

        guard let resolvedDepartureTime = normalizedISO8601(departureTime) else {
            errorMessage = "Enter a valid ISO 8601 departure time."
            return
        }

        guard let resolvedArrivalTime = normalizedISO8601(arrivalTime) else {
            errorMessage = "Enter a valid ISO 8601 arrival time."
            return
        }

        let trimmedPoints = pointsCost.trimmingCharacters(in: .whitespacesAndNewlines)
        var resolvedPoints: Int?
        if !trimmedPoints.isEmpty {
            guard trimmedPoints.allSatisfy({ $0.isNumber }), let value = Int(trimmedPoints) else {
                pointsCostError = "Enter a whole number"
                return
            }
            resolvedPoints = value
        }

        let payload = AddFlightPayload(
            airline: resolvedAirline,
            flightNumber: resolvedFlightNumber,
            airlineCode: resolvedAirlineCode,
            departureAirport: resolvedDepartureAirport,
            departureCode: resolvedDepartureCode,
            departureTime: resolvedDepartureTime,
            arrivalAirport: resolvedArrivalAirport,
            arrivalCode: resolvedArrivalCode,
            arrivalTime: resolvedArrivalTime,
            flightType: "manual",
            pointsCost: resolvedPoints
        )

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await viewModel.addManualFlight(payload: payload)
            dismiss()
            await viewModel.refresh()
        } catch let error as APIError {
            errorMessage = error.errorDescription ?? "Unable to add flight."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func requiredString(_ value: String, label: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            errorMessage = "Enter a \(label)."
            return nil
        }
        return trimmed
    }

    private func normalizedISO8601(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: trimmed) {
            return formatter.string(from: date)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: trimmed) {
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.string(from: date)
        }
        return nil
    }
}

#Preview {
    AddFlightSheetView(viewModel: FlightsViewModel(tripId: 1, flightsAPI: nil))
}
