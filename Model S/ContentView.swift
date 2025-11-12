//
//  ContentView.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        RideRequestView(
            onPickupSelected: { location in
                print("Pickup: \(location)")
            },
            onDestinationSelected: { location in
                print("Destination: \(location)")
            },
            onConfirmRide: {
                print("Ride confirmed!")
            }
        )
    }
}

#Preview {
    ContentView()
}
