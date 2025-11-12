//
//  ContentView.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var mapViewModel = MapViewModel()

    var body: some View {
        RideMapView(viewModel: mapViewModel)
            .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
