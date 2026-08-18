import Foundation

enum MLXMetalLibrary {
    private static let lock = NSLock()

    enum BootstrapError: LocalizedError {
        case bundledLibraryMissing
        case executableDirectoryMissing

        var errorDescription: String? {
            switch self {
            case .bundledLibraryMissing:
                return String(
                    localized: "core.mlx-metal-library.bundled-library-missing",
                    defaultValue: "The bundled MLX Metal library is missing. Rebuild the app with Sources/LabLLM/Resources/mlx.metallib included.",
                    comment: "Error shown when packaged MLX metallib resource is not found"
                )
            case .executableDirectoryMissing:
                return String(
                    localized: "core.mlx-metal-library.executable-folder-missing",
                    defaultValue: "Couldn't locate the app executable folder for MLX Metal setup.",
                    comment: "Error shown when executable directory cannot be determined during MLX setup"
                )
            }
        }
    }

    @discardableResult
    static func ensureAvailable() throws -> URL {
        lock.lock()
        defer { lock.unlock() }

        guard let bundled = Bundle.module.url(forResource: "mlx", withExtension: "metallib") ??
                Bundle.module.url(forResource: "default", withExtension: "metallib") else {
            throw BootstrapError.bundledLibraryMissing
        }
        guard let executableURL = Bundle.main.executableURL else {
            throw BootstrapError.executableDirectoryMissing
        }

        let executableDir = executableURL.deletingLastPathComponent()
        let preferredURL = executableDir.appendingPathComponent("mlx.metallib")
        let fallbackURL = executableDir.appendingPathComponent("default.metallib")

        try install(bundled, to: preferredURL)
        try install(bundled, to: fallbackURL)
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        try install(bundled, to: cwd.appendingPathComponent("mlx.metallib"))
        try install(bundled, to: cwd.appendingPathComponent("default.metallib"))
        return preferredURL
    }

    private static func install(_ source: URL, to destination: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path),
           (try? fm.attributesOfItem(atPath: destination.path)[.size] as? NSNumber) ==
            (try? fm.attributesOfItem(atPath: source.path)[.size] as? NSNumber) {
            return
        }

        let temp = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).tmp")
        try? fm.removeItem(at: temp)
        try fm.copyItem(at: source, to: temp)
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.moveItem(at: temp, to: destination)
    }
}
