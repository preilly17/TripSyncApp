//
//  ContentView.swift
//  TripSyncClean
//
//  Created by Patrick Reilly on 1/11/26.
//

import SwiftUI

struct ContentView: View {
    private let tripsAPI: TripsAPI?

    init(tripsAPI: TripsAPI? = (try? APIClient()).map { TripsAPI(client: $0) }) {
        self.tripsAPI = tripsAPI
    }

    var body: some View {
        NavigationStack {
            TripsListView(tripsAPI: tripsAPI)
        }
    }
}

#Preview {
    ContentView(tripsAPI: nil)
}
