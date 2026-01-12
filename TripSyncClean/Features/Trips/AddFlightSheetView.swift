import SwiftUI

struct AddFlightSheetView: View {
    @ObservedObject var viewModel: FlightsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var airline = ""
    @State private var flightNumber = ""
    @State private var departAirportCode = ""
    @State private var arriveAirportCode = ""
    @State private var departDatetime = ""
    @State private var arriveDatetime = ""
    @State private var status = ""
    @State private var bookingSource = ""
    @State private var pointsCost = ""

    @State private var pointsCostError: String?
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Flight Details") {
                    TextField("Airline", text: $airline)
                    TextField("Flight Number", text: $flightNumber)
                    TextField("Depart Airport Code", text: $departAirportCode)
                        .textInputAutocapitalization(.characters)
                    TextField("Arrive Airport Code", text: $arriveAirportCode)
                        .textInputAutocapitalization(.characters)
                    TextField("Depart Date/Time (ISO 8601)", text: $departDatetime)
                    TextField("Arrive Date/Time (ISO 8601)", text: $arriveDatetime)
                    TextField("Status", text: $status)
                    TextField("Booking Source", text: $bookingSource)
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
            airline: trimmedOrNil(airline),
            flightNumber: trimmedOrNil(flightNumber),
            departAirportCode: trimmedOrNil(departAirportCode),
            arriveAirportCode: trimmedOrNil(arriveAirportCode),
            departDatetime: trimmedOrNil(departDatetime),
            arriveDatetime: trimmedOrNil(arriveDatetime),
            status: trimmedOrNil(status),
            bookingSource: trimmedOrNil(bookingSource),
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

    private func trimmedOrNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    AddFlightSheetView(viewModel: FlightsViewModel(tripId: 1, flightsAPI: nil))
}
