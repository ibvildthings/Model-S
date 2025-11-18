//
//  AuthenticationFeature.swift
//  Model S
//
//  Public interface for the Authentication feature module
//  Other parts of the app should only interact with this protocol
//

import Foundation
import Combine

// MARK: - Authentication Feature Protocol

/// Public interface for the Authentication feature
/// This is the ONLY way other modules should interact with authentication
@MainActor
protocol AuthenticationFeature {
    // MARK: - State

    /// Current authenticated user
    var currentUser: User? { get }

    /// Whether user is authenticated
    var isAuthenticated: Bool { get }

    /// Observable publisher for authentication state changes
    var authStatePublisher: AnyPublisher<AuthState, Never> { get }

    // MARK: - Actions

    /// Sign in with email and password
    func signIn(email: String, password: String) async throws

    /// Sign up with user details
    func signUp(email: String, password: String, name: String) async throws

    /// Sign out current user
    func signOut() async throws

    /// Request password reset
    func resetPassword(email: String) async throws

    /// Check if session is valid
    func validateSession() async -> Bool
}

// MARK: - Authentication State

/// Represents the current authentication state
enum AuthState: Equatable {
    case unauthenticated
    case authenticating
    case authenticated(User)
    case error(AuthError)
}

// MARK: - Authentication Errors

/// Errors that can occur during authentication
enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case userNotFound
    case emailAlreadyInUse
    case weakPassword
    case networkError
    case sessionExpired
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .userNotFound:
            return "User not found"
        case .emailAlreadyInUse:
            return "Email already in use"
        case .weakPassword:
            return "Password is too weak"
        case .networkError:
            return "Network connection failed"
        case .sessionExpired:
            return "Your session has expired. Please sign in again"
        case .unknown(let error):
            return "Authentication failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Authentication Feature Implementation

/// Default implementation of AuthenticationFeature
/// This is the actual feature implementation that can be replaced/mocked
@MainActor
class AuthenticationModule: AuthenticationFeature, ObservableObject {

    // MARK: - Dependencies

    private let authService: AuthService
    private let stateStore: AppStateStore

    // MARK: - Published State

    @Published private(set) var currentUser: User?
    @Published private(set) var isAuthenticated: Bool = false

    private let authStateSubject = CurrentValueSubject<AuthState, Never>(.unauthenticated)

    var authStatePublisher: AnyPublisher<AuthState, Never> {
        authStateSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    init(authService: AuthService, stateStore: AppStateStore) {
        self.authService = authService
        self.stateStore = stateStore

        // Load persisted session
        Task {
            await checkPersistedSession()
        }
    }

    // MARK: - Public Methods

    func signIn(email: String, password: String) async throws {
        authStateSubject.send(.authenticating)

        do {
            let user = try await authService.signIn(email: email, password: password)
            handleSuccessfulAuth(user)
        } catch {
            let authError = mapToAuthError(error)
            authStateSubject.send(.error(authError))
            throw authError
        }
    }

    func signUp(email: String, password: String, name: String) async throws {
        authStateSubject.send(.authenticating)

        do {
            let user = try await authService.signUp(email: email, password: password, name: name)
            handleSuccessfulAuth(user)
        } catch {
            let authError = mapToAuthError(error)
            authStateSubject.send(.error(authError))
            throw authError
        }
    }

    func signOut() async throws {
        do {
            try await authService.signOut()
            handleSignOut()
        } catch {
            let authError = mapToAuthError(error)
            authStateSubject.send(.error(authError))
            throw authError
        }
    }

    func resetPassword(email: String) async throws {
        do {
            try await authService.resetPassword(email: email)
        } catch {
            let authError = mapToAuthError(error)
            throw authError
        }
    }

    func validateSession() async -> Bool {
        do {
            return try await authService.validateSession()
        } catch {
            return false
        }
    }

    // MARK: - Private Methods

    private func checkPersistedSession() async {
        guard await validateSession() else {
            handleSignOut()
            return
        }

        // Load user from persisted session
        if let user = authService.getCurrentUser() {
            handleSuccessfulAuth(user)
        }
    }

    private func handleSuccessfulAuth(_ user: User) {
        currentUser = user
        isAuthenticated = true
        authStateSubject.send(.authenticated(user))
        stateStore.dispatch(.setUser(user))
    }

    private func handleSignOut() {
        currentUser = nil
        isAuthenticated = false
        authStateSubject.send(.unauthenticated)
        stateStore.dispatch(.logout)
    }

    private func mapToAuthError(_ error: Error) -> AuthError {
        // Map service-specific errors to AuthError
        if let authError = error as? AuthError {
            return authError
        }
        return .unknown(error)
    }
}

// MARK: - Auth Service Protocol

/// Protocol for authentication services (Firebase, custom backend, etc.)
protocol AuthService {
    func signIn(email: String, password: String) async throws -> User
    func signUp(email: String, password: String, name: String) async throws -> User
    func signOut() async throws
    func resetPassword(email: String) async throws
    func validateSession() async throws -> Bool
    func getCurrentUser() -> User?
}

// MARK: - Mock Auth Service

/// Mock authentication service for development/testing
class MockAuthService: AuthService {
    private var mockUser: User?

    func signIn(email: String, password: String) async throws -> User {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Simple validation
        guard !email.isEmpty, password.count >= 6 else {
            throw AuthError.invalidCredentials
        }

        let user = User(
            id: UUID().uuidString,
            name: "Test User",
            email: email,
            phoneNumber: nil,
            isDriver: false
        )

        mockUser = user
        return user
    }

    func signUp(email: String, password: String, name: String) async throws -> User {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Simple validation
        guard !email.isEmpty else {
            throw AuthError.invalidCredentials
        }

        guard password.count >= 6 else {
            throw AuthError.weakPassword
        }

        let user = User(
            id: UUID().uuidString,
            name: name,
            email: email,
            phoneNumber: nil,
            isDriver: false
        )

        mockUser = user
        return user
    }

    func signOut() async throws {
        mockUser = nil
    }

    func resetPassword(email: String) async throws {
        // Simulate success
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    func validateSession() async throws -> Bool {
        return mockUser != nil
    }

    func getCurrentUser() -> User? {
        return mockUser
    }
}
