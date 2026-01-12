import SwiftUI

struct AddFlightSheetView: View {
    @ObservedObject var viewModel: FlightsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var airline = ""
    @State private var airlineCode = ""
    @State private var flightNumber = ""
    @State private var departureAirport = ""
    @State private var departureCode = ""
    @State private var departDate = Date()
    @State private var arrivalAirport = ""
    @State private var arrivalCode = ""
    @State private var arriveDate = Date()
    @State private var pointsCost = ""

    @State private var pointsCostError: String?
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var showingDeparturePicker = false
    @State private var showingArrivalPicker = false

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
                    Button {
                        showingDeparturePicker = true
                    } label: {
                        HStack {
                            Text("Departure Time")
                            Spacer()
                            Text(displayDateFormatter.string(from: departDate))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingArrivalPicker = true
                    } label: {
                        HStack {
                            Text("Arrival Time")
                            Spacer()
                            Text(displayDateFormatter.string(from: arriveDate))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
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
            .sheet(isPresented: $showingDeparturePicker) {
                NavigationStack {
                    VStack {
                        DatePicker(
                            "Departure Time",
                            selection: $departDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                    }
                    .padding()
                    .navigationTitle("Departure Time")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingDeparturePicker = false
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingArrivalPicker) {
                NavigationStack {
                    VStack {
                        DatePicker(
                            "Arrival Time",
                            selection: $arriveDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                    }
                    .padding()
                    .navigationTitle("Arrival Time")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingArrivalPicker = false
                            }
                        }
                    }
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

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let resolvedDepartureTime = formatter.string(from: departDate)
        let resolvedArrivalTime = formatter.string(from: arriveDate)

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
}

private let displayDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

#Preview {
    AddFlightSheetView(viewModel: FlightsViewModel(tripId: 1, flightsAPI: nil))
}
