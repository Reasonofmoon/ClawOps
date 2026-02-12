@preconcurrency import Foundation

final class ProcessRunner: @unchecked Sendable {
    private var process: Process?

    var isRunning: Bool {
        process?.isRunning ?? false
    }

    func run(command: [String], onOutput: @escaping @Sendable (String) -> Void, onComplete: @escaping @Sendable (Int32) -> Void) {
        stop()

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = command

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            guard let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { onOutput(text) }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            guard let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { onOutput(text) }
        }

        task.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                self?.process = nil
                onComplete(proc.terminationStatus)
            }
        }

        do {
            try task.run()
            process = task
        } catch {
            DispatchQueue.main.async {
                onOutput("실행 실패: \(error.localizedDescription)\n")
                onComplete(1)
            }
        }
    }

    func stop() {
        guard let process, process.isRunning else { return }
        process.terminate()
        self.process = nil
    }
}
