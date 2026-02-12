import Foundation
import Combine
#if canImport(AppKit)
import AppKit
#endif

@MainActor
final class AppViewModel: ObservableObject, @unchecked Sendable {
    @Published var requestText: String = ""
    @Published var outputText: String = ""
    @Published var selectedMode: RunMode = .auto
    @Published var thinkingLevel: String = "medium"
    @Published var useRemote: Bool = false
    @Published var saveOutputToFile: Bool = true

    @Published var presets: [Preset] = []
    @Published var selectedPresetName: String = ""

    @Published var skillSnippets: [SkillSnippet] = [
        SkillSnippet(title: "정확성 우선", body: "불확실한 사실은 추정으로 단정하지 말고 불확실성을 명시하라."),
        SkillSnippet(title: "실행 우선", body: "결과물은 바로 실행 가능한 단계와 명령 중심으로 작성하라."),
        SkillSnippet(title: "코딩 엄격", body: "코드 작업은 계획-수정-검증 순서로 진행하고 검증 결과를 반드시 기록하라.")
    ]
    @Published var selectedSkillTitles: Set<String> = []

    @Published var profiles: [AgentProfile] = []
    @Published var selectedProfileID: String = ""

    @Published var skillPacks: [SkillPack] = []
    @Published var selectedSkillPackID: String = ""

    @Published var policy = PolicyConfig(
        allowRemote: false,
        requirePreflightPass: true,
        maxRequestCharacters: 5000,
        blockedModes: []
    )

    @Published var runbookRules: [RunbookRule] = []
    @Published var preflightChecks: [PreflightCheck] = []
    @Published var lastRunbookRecommendation: String = ""

    private let runner = ProcessRunner()
    private var currentRunBuffer: String = ""
    private var outputBuffer: String = ""
    private var outputFlushWorkItem: DispatchWorkItem?
    private var didTrimOutput: Bool = false
    private let outputFlushInterval: TimeInterval = 0.15
    private let maxOutputCharacters: Int = 120_000
    private let maxRunBufferCharacters: Int = 40_000
    private let workspaceRoot: String

    private var botScript: String { "\(workspaceRoot)/scripts/bot" }
    private var presetsFile: String { "\(workspaceRoot)/presets/default.tsv" }
    private var defaultOutputDir: String { "\(workspaceRoot)/outputs" }
    private var controlConfigDir: String { "\(workspaceRoot)/OpenClawControlApp/config" }

    private var profilesFile: String { "\(controlConfigDir)/profiles.json" }
    private var skillPacksFile: String { "\(controlConfigDir)/skillpacks.json" }
    private var policyFile: String { "\(controlConfigDir)/policy.json" }
    private var runbooksFile: String { "\(controlConfigDir)/runbooks.json" }

    init() {
        self.workspaceRoot = Self.resolveWorkspaceRoot()
    }

    var isRunning: Bool {
        runner.isRunning
    }

    func bootstrapAndLoad() {
        bootstrapControlConfigsIfNeeded()
        loadControlConfigs()
        loadPresets()
        appendOutput("초기 로드 완료. Preflight는 '점검 실행' 버튼으로 실행하세요.\n")
    }

    func loadPresets() {
        do {
            let raw = try String(contentsOfFile: presetsFile, encoding: .utf8)
            let rows = raw
                .split(separator: "\n")
                .map(String.init)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .filter { !$0.hasPrefix("#") }

            let parsed = rows.compactMap { line -> Preset? in
                let fields = line.components(separatedBy: "\t")
                guard fields.count >= 3 else { return nil }
                return Preset(name: fields[0], mode: fields[1], request: fields[2])
            }

            presets = parsed
            if selectedPresetName.isEmpty, let first = parsed.first {
                selectedPresetName = first.name
            }
        } catch {
            appendOutput("프리셋 로딩 실패: \(error.localizedDescription)\n")
        }
    }

    func applySelectedPresetToRequest() {
        guard let preset = presets.first(where: { $0.name == selectedPresetName }) else {
            appendOutput("선택된 프리셋을 찾을 수 없습니다.\n")
            return
        }
        requestText = preset.request

        if let mode = RunMode(rawValue: preset.mode) {
            selectedMode = mode
        } else {
            selectedMode = .auto
        }

        appendOutput("프리셋 적용: \(preset.displayLabel)\n")
    }

    func applySelectedProfile() {
        guard let p = profiles.first(where: { $0.id == selectedProfileID }) else { return }
        selectedMode = p.mode
        thinkingLevel = p.thinking
        useRemote = p.useRemote
        saveOutputToFile = p.saveOutputToFile
        if !p.defaultPreset.isEmpty { selectedPresetName = p.defaultPreset }
        appendOutput("프로필 적용: \(p.name)\n")
    }

    func saveCurrentToSelectedProfile() {
        guard let idx = profiles.firstIndex(where: { $0.id == selectedProfileID }) else { return }
        profiles[idx].mode = selectedMode
        profiles[idx].thinking = thinkingLevel
        profiles[idx].useRemote = useRemote
        profiles[idx].saveOutputToFile = saveOutputToFile
        profiles[idx].defaultPreset = selectedPresetName
        saveJSON(profiles, to: profilesFile)
        appendOutput("프로필 저장: \(profiles[idx].name)\n")
    }

    func applySelectedSkillPack() {
        guard let pack = skillPacks.first(where: { $0.id == selectedSkillPackID }) else { return }
        selectedSkillTitles = Set(pack.skillTitles)
        appendOutput("스킬팩 적용: \(pack.name)\n")
    }

    func saveCurrentToSelectedSkillPack() {
        guard let idx = skillPacks.firstIndex(where: { $0.id == selectedSkillPackID }) else { return }
        skillPacks[idx].skillTitles = Array(selectedSkillTitles).sorted()
        saveJSON(skillPacks, to: skillPacksFile)
        appendOutput("스킬팩 저장: \(skillPacks[idx].name)\n")
    }

    func savePolicy() {
        saveJSON(policy, to: policyFile)
        appendOutput("정책 저장 완료\n")
    }

    func runCheck() {
        run(command: ["bash", botScript, "check"])
    }

    func runPreflight() {
        let botScript = self.botScript
        let presetsFile = self.presetsFile
        let defaultOutputDir = self.defaultOutputDir
        appendOutput("Preflight 점검 시작...\n")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let checks = Self.collectPreflightChecks(
                botScript: botScript,
                presetsFile: presetsFile,
                defaultOutputDir: defaultOutputDir
            )
            DispatchQueue.main.async {
                guard let self else { return }
                self.preflightChecks = checks
                self.appendOutput("Preflight 완료: pass \(checks.filter { $0.status == .pass }.count), warn \(checks.filter { $0.status == .warn }.count), fail \(checks.filter { $0.status == .fail }.count)\n")
            }
        }
    }

    func runTask() {
        let trimmed = requestText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            appendOutput("요청을 입력하세요.\n")
            return
        }

        guard validateAgainstPolicy(request: trimmed, mode: selectedMode) else { return }

        let fullRequest = buildRequestWithSkills(base: trimmed)
        var command = ["bash", botScript]

        if selectedMode == .auto {
            command += ["ask", fullRequest]
        } else {
            command += ["run", selectedMode.rawValue, fullRequest]
        }

        command += ["--thinking", thinkingLevel]

        if useRemote {
            command += ["--remote"]
        }

        if saveOutputToFile {
            let timestamp = Self.timestampString()
            let fileName = "app-\(selectedMode.rawValue)-\(timestamp).md"
            let outPath = "\(defaultOutputDir)/\(fileName)"
            command += ["--out", outPath]
        }

        run(command: command)
    }

    func runQuickPreset() {
        guard !selectedPresetName.isEmpty else {
            appendOutput("프리셋을 선택하세요.\n")
            return
        }

        guard let preset = presets.first(where: { $0.name == selectedPresetName }) else {
            appendOutput("선택된 프리셋을 찾을 수 없습니다.\n")
            return
        }

        let presetRequest = preset.request.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !presetRequest.isEmpty else {
            appendOutput("프리셋 요청이 비어 있습니다.\n")
            return
        }

        let presetMode = RunMode(rawValue: preset.mode) ?? selectedMode
        guard validateAgainstPolicy(request: presetRequest, mode: presetMode) else { return }

        var command = ["bash", botScript, "quick", selectedPresetName, "--thinking", thinkingLevel]
        if useRemote {
            command += ["--remote"]
        }

        if saveOutputToFile {
            let timestamp = Self.timestampString()
            let fileName = "app-quick-\(selectedPresetName)-\(timestamp).md"
            command += ["--out", "\(defaultOutputDir)/\(fileName)"]
        }

        run(command: command)
    }

    func stop() {
        runner.stop()
        appendOutput("실행 중단 요청을 보냈습니다.\n")
    }

    func clearOutput() {
        outputFlushWorkItem?.cancel()
        outputFlushWorkItem = nil
        outputBuffer = ""
        didTrimOutput = false
        currentRunBuffer = ""
        outputText = ""
        lastRunbookRecommendation = ""
    }

    func pasteRequestFromClipboard() {
        #if canImport(AppKit)
        let pb = NSPasteboard.general
        if let text = pb.string(forType: .string), !text.isEmpty {
            requestText = text
            appendOutput("클립보드에서 요청을 붙여넣었습니다.\\n")
        } else {
            appendOutput("클립보드에 텍스트가 없습니다.\\n")
        }
        #else
        appendOutput("현재 플랫폼에서는 클립보드 붙여넣기를 지원하지 않습니다.\\n")
        #endif
    }

    private func run(command: [String]) {
        appendOutput("\n$ \(command.joined(separator: " "))\n")
        currentRunBuffer = ""

        runner.run(command: command, onOutput: { [weak self] text in
            Task { @MainActor in
                self?.appendRunBuffer(text)
                self?.appendOutput(text)
            }
        }, onComplete: { [weak self] status in
            Task { @MainActor in
                self?.appendOutput("\n종료 코드: \(status)\n")
                self?.evaluateRunbook(exitCode: status)
            }
        })
    }

    private func validateAgainstPolicy(request: String, mode: RunMode) -> Bool {
        if !policy.allowRemote && useRemote {
            appendOutput("정책 위반: Remote 실행이 금지되어 있습니다.\n")
            return false
        }

        if policy.blockedModes.contains(mode) {
            appendOutput("정책 위반: \(mode.rawValue) 모드는 차단되어 있습니다.\n")
            return false
        }

        if request.count > policy.maxRequestCharacters {
            appendOutput("정책 위반: 요청 길이(\(request.count))가 제한(\(policy.maxRequestCharacters))을 초과했습니다.\n")
            return false
        }

        if policy.requirePreflightPass {
            let hasFail = preflightChecks.contains { $0.status == .fail }
            if hasFail {
                appendOutput("정책 위반: Preflight 실패 항목이 있어 실행할 수 없습니다.\n")
                return false
            }
        }

        return true
    }

    private func buildRequestWithSkills(base: String) -> String {
        let activeSnippets = skillSnippets.filter { selectedSkillTitles.contains($0.title) }
        let selectedPack = skillPacks.first(where: { $0.id == selectedSkillPackID })

        let snippetText = activeSnippets
            .map { "- [\($0.title)] \($0.body)" }
            .joined(separator: "\n")

        let packText = (selectedPack?.extraInstructions ?? [])
            .map { "- \($0)" }
            .joined(separator: "\n")

        let merged = [snippetText, packText]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")

        guard !merged.isEmpty else { return base }

        return """
        [스킬 지시]
        \(merged)

        [사용자 요청]
        \(base)
        """
    }

    private func evaluateRunbook(exitCode: Int32) {
        let hay = currentRunBuffer.lowercased()
        let hasAuthSignal = Self.containsAuthFailureSignal(hay)

        if exitCode == 0 && !hasAuthSignal {
            lastRunbookRecommendation = ""
            return
        }

        if exitCode == 127 || hay.contains("command not found") {
            lastRunbookRecommendation = "[실행 파일 누락] 종료코드 127은 보통 명령 경로 문제입니다. `scripts/assistantctl`이 `/opt/homebrew/bin/openclaw`를 찾는지 확인하고, 앱에서 다시 상태 체크를 실행하세요."
            appendOutput("런북 추천: \(lastRunbookRecommendation)\n")
            return
        }

        if let matched = runbookRules.first(where: { hay.contains($0.triggerPattern.lowercased()) }) {
            lastRunbookRecommendation = "[\(matched.name)] \(matched.recommendation)"
            appendOutput("런북 추천: \(lastRunbookRecommendation)\n")
        } else {
            lastRunbookRecommendation = "실패 패턴에 맞는 런북이 없어 수동 점검이 필요합니다."
            appendOutput("런북 추천: \(lastRunbookRecommendation)\n")
        }
    }

    private func appendOutput(_ text: String) {
        outputBuffer += text
        scheduleOutputFlushIfNeeded()
    }

    private func appendRunBuffer(_ text: String) {
        currentRunBuffer += text
        if currentRunBuffer.count > maxRunBufferCharacters {
            currentRunBuffer = String(currentRunBuffer.suffix(maxRunBufferCharacters))
        }
    }

    private func scheduleOutputFlushIfNeeded() {
        guard outputFlushWorkItem == nil else { return }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.flushOutputBuffer()
        }
        outputFlushWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + outputFlushInterval, execute: workItem)
    }

    private func flushOutputBuffer() {
        outputFlushWorkItem = nil
        guard !outputBuffer.isEmpty else { return }

        outputText += outputBuffer
        outputBuffer = ""

        if outputText.count > maxOutputCharacters {
            outputText = String(outputText.suffix(maxOutputCharacters))
            if !didTrimOutput {
                outputText = "…(로그가 길어 일부를 생략했습니다)\n" + outputText
                didTrimOutput = true
            }
        }
    }

    private static func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private func shell(_ args: [String]) -> (exitCode: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
        } catch {
            return (1, error.localizedDescription)
        }
    }

    private nonisolated static func containsAuthFailureSignal(_ text: String) -> Bool {
        text.contains("http 401") ||
            text.contains("authentication_error") ||
            text.contains("invalid x-api-key") ||
            text.contains("authentication failed") ||
            text.contains("invalid api key")
    }

    private nonisolated static func collectPreflightChecks(
        botScript: String,
        presetsFile: String,
        defaultOutputDir: String
    ) -> [PreflightCheck] {
        var checks: [PreflightCheck] = []

        let openclawAvailable = shellSync(["bash", "-lc", "command -v openclaw >/dev/null 2>&1"])
        checks.append(PreflightCheck(
            title: "OpenClaw 명령",
            status: openclawAvailable.exitCode == 0 ? .pass : .fail,
            detail: openclawAvailable.exitCode == 0 ? "정상" : "openclaw 명령을 찾을 수 없습니다."
        ))

        let botExists = FileManager.default.isReadableFile(atPath: botScript)
        checks.append(PreflightCheck(
            title: "bot 스크립트",
            status: botExists ? .pass : .fail,
            detail: botExists ? "정상" : "\(botScript) 경로를 확인하세요."
        ))

        let presetsExists = FileManager.default.fileExists(atPath: presetsFile)
        checks.append(PreflightCheck(
            title: "프리셋 파일",
            status: presetsExists ? .pass : .warn,
            detail: presetsExists ? "정상" : "프리셋 없이 수동 요청만 가능"
        ))

        do {
            try FileManager.default.createDirectory(atPath: defaultOutputDir, withIntermediateDirectories: true)
            checks.append(PreflightCheck(title: "출력 디렉토리", status: .pass, detail: defaultOutputDir))
        } catch {
            checks.append(PreflightCheck(title: "출력 디렉토리", status: .fail, detail: error.localizedDescription))
        }

        let statusProbe = shellSync(["bash", botScript, "check"])
        checks.append(PreflightCheck(
            title: "런타임 상태 점검",
            status: statusProbe.exitCode == 0 ? .pass : .warn,
            detail: statusProbe.exitCode == 0 ? "정상" : "OpenClaw 상태 점검 경고 (로그 확인)"
        ))

        if openclawAvailable.exitCode == 0 {
            let authProbe = shellSync([
                "openclaw", "agent",
                "--session-id", "preflight-auth",
                "--thinking", "minimal",
                "--message", "preflight auth ping",
                "--local"
            ])
            let authText = authProbe.output.lowercased()
            if containsAuthFailureSignal(authText) {
                checks.append(PreflightCheck(
                    title: "모델 인증 스모크 테스트",
                    status: .fail,
                    detail: "401/인증 오류 감지. API 키/토큰 및 공급자 매핑을 확인하세요."
                ))
            } else if authProbe.exitCode == 0 {
                checks.append(PreflightCheck(
                    title: "모델 인증 스모크 테스트",
                    status: .pass,
                    detail: "정상"
                ))
            } else if authText.contains("operation not permitted") {
                checks.append(PreflightCheck(
                    title: "모델 인증 스모크 테스트",
                    status: .warn,
                    detail: "권한 문제로 검사 생략됨(환경 권한 확인 필요)."
                ))
            } else {
                checks.append(PreflightCheck(
                    title: "모델 인증 스모크 테스트",
                    status: .warn,
                    detail: "실패(exit \(authProbe.exitCode)). 로그를 확인하세요."
                ))
            }
        } else {
            checks.append(PreflightCheck(
                title: "모델 인증 스모크 테스트",
                status: .warn,
                detail: "openclaw 명령 미탐지로 검사 생략"
            ))
        }

        return checks
    }

    private nonisolated static func shellSync(_ args: [String]) -> (exitCode: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
        } catch {
            return (1, error.localizedDescription)
        }
    }

    private static func resolveWorkspaceRoot() -> String {
        let fm = FileManager.default
        if let envRoot = ProcessInfo.processInfo.environment["OPENCLAW_ROOT"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !envRoot.isEmpty {
            let normalized = normalizePath(envRoot)
            if isValidWorkspaceRoot(normalized) {
                return normalized
            }
        }

        let cwd = normalizePath(fm.currentDirectoryPath)
        if let found = findWorkspaceRoot(startingAt: cwd) {
            return found
        }

        if let execDir = Bundle.main.executableURL?.deletingLastPathComponent().path,
           let found = findWorkspaceRoot(startingAt: execDir) {
            return found
        }

        let home = NSHomeDirectory()
        if !home.isEmpty {
            let direct = "\(home)/openclaw"
            if isValidWorkspaceRoot(direct) {
                return direct
            }
        }

        return cwd
    }

    private static func findWorkspaceRoot(startingAt path: String) -> String? {
        var current = normalizePath(path)
        var visited = Set<String>()
        var depth = 0

        while !current.isEmpty && depth < 64 {
            if visited.contains(current) { break }
            visited.insert(current)

            if isValidWorkspaceRoot(current) {
                return current
            }

            let parent = (current as NSString).deletingLastPathComponent
            if parent == current || parent.isEmpty {
                break
            }
            current = parent
            depth += 1
        }
        return nil
    }

    private static func normalizePath(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        if trimmed.hasPrefix("file://"), let url = URL(string: trimmed), url.isFileURL {
            return url.path
        }
        return (trimmed as NSString).standardizingPath
    }

    private static func isValidWorkspaceRoot(_ path: String) -> Bool {
        let fm = FileManager.default
        return fm.isReadableFile(atPath: "\(path)/scripts/bot")
            && fm.fileExists(atPath: "\(path)/presets/default.tsv")
    }

    private func bootstrapControlConfigsIfNeeded() {
        do {
            try FileManager.default.createDirectory(atPath: controlConfigDir, withIntermediateDirectories: true)
        } catch {
            appendOutput("설정 디렉토리 생성 실패: \(error.localizedDescription)\n")
            return
        }

        if !FileManager.default.fileExists(atPath: profilesFile) {
            let defaults = [
                AgentProfile(id: "default", name: "Default Safe", mode: .auto, thinking: "medium", useRemote: false, saveOutputToFile: true, defaultPreset: "bugfix"),
                AgentProfile(id: "research", name: "Research Pro", mode: .research, thinking: "high", useRemote: false, saveOutputToFile: true, defaultPreset: "research-daily")
            ]
            saveJSON(defaults, to: profilesFile)
        }

        if !FileManager.default.fileExists(atPath: skillPacksFile) {
            let defaults = [
                SkillPack(id: "coding-strict", name: "Coding Strict", skillTitles: ["정확성 우선", "코딩 엄격"], extraInstructions: ["변경 파일과 검증 명령을 반드시 출력하라."]),
                SkillPack(id: "research-brief", name: "Research Brief", skillTitles: ["정확성 우선", "실행 우선"], extraInstructions: ["핵심 결론, 근거, 리스크 순서로 요약하라."])
            ]
            saveJSON(defaults, to: skillPacksFile)
        }

        if !FileManager.default.fileExists(atPath: policyFile) {
            saveJSON(policy, to: policyFile)
        }

        if !FileManager.default.fileExists(atPath: runbooksFile) {
            let defaults = [
                RunbookRule(id: "missing-key", name: "API 키 누락", triggerPattern: "api key", recommendation: "openclaw configure에서 모델/API 키를 먼저 설정하세요."),
                RunbookRule(id: "invalid-x-api-key", name: "API 키 불일치", triggerPattern: "invalid x-api-key", recommendation: "현재 키가 선택한 공급자와 맞지 않습니다. 공급자별 키를 다시 매핑하거나 Claude fallback 경로를 사용하세요."),
                RunbookRule(id: "auth-401", name: "인증 실패(401)", triggerPattern: "http 401", recommendation: "401은 인증 토큰/키 불일치입니다. 모델 공급자와 키 타입(api-key vs token)을 점검하세요."),
                RunbookRule(id: "command-not-found", name: "명령 경로 오류", triggerPattern: "command not found", recommendation: "종료코드 127은 명령 경로 문제일 가능성이 큽니다. /opt/homebrew/bin/openclaw 존재 여부와 PATH를 점검하세요."),
                RunbookRule(id: "permission", name: "권한 오류", triggerPattern: "operation not permitted", recommendation: "권한 설정(Accessibility/Automation/파일 접근)과 경로 권한을 확인하세요."),
                RunbookRule(id: "network", name: "네트워크 오류", triggerPattern: "could not resolve host", recommendation: "DNS/네트워크 상태를 확인하고 동일 요청을 재시도하세요.")
            ]
            saveJSON(defaults, to: runbooksFile)
        }
    }

    private func loadControlConfigs() {
        profiles = loadJSON([AgentProfile].self, from: profilesFile) ?? []
        if selectedProfileID.isEmpty { selectedProfileID = profiles.first?.id ?? "" }

        skillPacks = loadJSON([SkillPack].self, from: skillPacksFile) ?? []
        if selectedSkillPackID.isEmpty { selectedSkillPackID = skillPacks.first?.id ?? "" }

        if let loadedPolicy = loadJSON(PolicyConfig.self, from: policyFile) {
            policy = loadedPolicy
        }

        runbookRules = loadJSON([RunbookRule].self, from: runbooksFile) ?? []

        applySelectedProfile()
        applySelectedSkillPack()
    }

    private func saveJSON<T: Encodable>(_ value: T, to path: String) {
        do {
            let data = try JSONEncoder.pretty.encode(value)
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        } catch {
            appendOutput("저장 실패(\(path)): \(error.localizedDescription)\n")
        }
    }

    private func loadJSON<T: Decodable>(_ type: T.Type, from path: String) -> T? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            appendOutput("로드 실패(\(path)): \(error.localizedDescription)\n")
            return nil
        }
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
