//
//  AppLog.swift
//  Model S
//
//  Thin wrapper over os.Logger so logs show up in Console.app with levels and
//  categories, can be filtered, and debug noise is not persisted in release.
//
//  Usage: AppLog.debug("…"), AppLog.info("…"), AppLog.warning("…"), AppLog.error("…")
//  The category defaults to the calling file's name.
//

import Foundation
import os

enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Model-S"

    /// Named loggers for call sites that want a fixed category
    static let map = Logger(subsystem: subsystem, category: "map")
    static let network = Logger(subsystem: subsystem, category: "network")

    static func debug(_ message: String, fileID: String = #fileID) {
        logger(for: fileID).debug("\(message, privacy: .public)")
    }

    static func info(_ message: String, fileID: String = #fileID) {
        logger(for: fileID).info("\(message, privacy: .public)")
    }

    static func warning(_ message: String, fileID: String = #fileID) {
        logger(for: fileID).warning("\(message, privacy: .public)")
    }

    static func error(_ message: String, fileID: String = #fileID) {
        logger(for: fileID).error("\(message, privacy: .public)")
    }

    private static func logger(for fileID: String) -> Logger {
        // "Model_S/RideFlowController.swift" -> "RideFlowController"
        let file = fileID.split(separator: "/").last.map(String.init) ?? fileID
        let category = file.replacingOccurrences(of: ".swift", with: "")
        return Logger(subsystem: subsystem, category: category)
    }
}
