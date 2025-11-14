//
//  Debounce.swift
//  Model S
//
//  Reusable debouncing utility to prevent excessive API calls while user is typing.
//  Automatically cancels previous tasks when new input arrives.
//
//  Created by Pritesh Desai on 11/13/25.
//

import Foundation

/// A simple debouncer that delays execution until input stops changing
///
/// Usage:
/// ```swift
/// let debouncer = Debouncer(delay: 1.0)
/// debouncer.debounce {
///     await performExpensiveOperation()
/// }
/// ```
@MainActor
class Debouncer {
    /// Current pending task (cancelled when new debounce is triggered)
    private var task: Task<Void, Never>?

    /// Delay in seconds before executing the action
    private let delay: TimeInterval

    /// Creates a new debouncer with specified delay
    /// - Parameter delay: Time to wait (in seconds) before executing action
    init(delay: TimeInterval) {
        self.delay = delay
    }

    /// Debounces the given action - cancels previous action and schedules new one
    /// - Parameter action: The async action to perform after delay
    func debounce(_ action: @escaping () async -> Void) {
        // Cancel any previous pending task
        task?.cancel()

        // Create new task with delay
        task = Task { @MainActor in
            // Wait for the debounce delay
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            // Check if task was cancelled during sleep
            guard !Task.isCancelled else { return }

            // Execute the action
            await action()
        }
    }

    /// Cancels any pending debounced action
    func cancel() {
        task?.cancel()
        task = nil
    }

    /// Cleanup - cancels any pending task when debouncer is deallocated
    /// Note: deinit is nonisolated, so we access task directly (safe because it's just cancelling)
    deinit {
        task?.cancel()
    }
}
