//
//  HomeView.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import SwiftUI

struct HomeView: View {
    @State private var showRideRequest = false
    @State private var showDrive = false
    @State private var showRideHistory = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // App Title
                    VStack(spacing: 12) {
                        Image(systemName: "bolt.car.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.white)

                        Text("Model S")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 64)

                    // Buttons Container
                    VStack(spacing: 16) {
                        // Order a Ride Button
                        Button(action: {
                            showRideRequest = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "location.fill")
                                    .font(.title3)

                                Text("Order a ride")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(16)
                        }

                        // Drive Button
                        Button(action: {
                            showDrive = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "steeringwheel")
                                    .font(.title3)

                                Text("Drive")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        }

                        // Ride History Button
                        Button(action: {
                            showRideHistory = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.title3)

                                Text("Ride History")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .navigationDestination(isPresented: $showRideRequest) {
                ProductionExampleView()
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                showRideRequest = false
                            }) {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(.primary)
                                Text("Back")
                                    .foregroundColor(.primary)
                            }
                        }
                    }
            }
            .navigationDestination(isPresented: $showDrive) {
                DriverAppView()
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                showDrive = false
                            }) {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(.primary)
                                Text("Back")
                                    .foregroundColor(.primary)
                            }
                        }
                    }
            }
            .sheet(isPresented: $showRideHistory) {
                RideHistoryView()
            }
        }
    }
}

#Preview {
    HomeView()
}
