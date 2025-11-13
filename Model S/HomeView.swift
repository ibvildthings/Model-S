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

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    // App Title
                    VStack(spacing: 8) {
                        Image(systemName: "bolt.car.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white)

                        Text("Model S")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 60)

                    // Order a Ride Button
                    Button(action: {
                        showRideRequest = true
                    }) {
                        HStack {
                            Image(systemName: "location.fill")
                                .font(.title2)

                            Text("Order a ride")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)

                    // Drive Button
                    Button(action: {
                        showDrive = true
                    }) {
                        HStack {
                            Image(systemName: "steering.wheel")
                                .font(.title2)

                            Text("Drive")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)

                    Spacer()
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
                DriveView(onDismiss: {
                    showDrive = false
                })
            }
        }
    }
}

// Placeholder for Drive feature
struct DriveView: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                Spacer()

                Image(systemName: "steering.wheel")
                    .font(.system(size: 100))
                    .foregroundColor(.white)

                Text("Drive Mode")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 20)

                Text("Coming Soon")
                    .font(.title3)
                    .foregroundColor(.gray)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                    Text("Back")
                        .foregroundColor(.white)
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
