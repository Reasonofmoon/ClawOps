import Foundation

enum RunMode: String, CaseIterable, Identifiable, Codable {
    case auto = "auto"
    case crawl = "crawl"
    case research = "research"
    case doc = "doc"
    case content = "content"
    case code = "code"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "자동(ask)"
        case .crawl: return "크롤링(crawl)"
        case .research: return "리서치(research)"
        case .doc: return "문서(doc)"
        case .content: return "콘텐츠(content)"
        case .code: return "코딩(code)"
        }
    }
}

struct Preset: Identifiable, Hashable {
    let name: String
    let mode: String
    let request: String

    var id: String { name }
    var displayLabel: String { "\(name) (\(mode))" }
}

struct SkillSnippet: Identifiable, Hashable {
    var id: String { title }
    var title: String
    var body: String
}

struct AgentProfile: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var mode: RunMode
    var thinking: String
    var useRemote: Bool
    var saveOutputToFile: Bool
    var defaultPreset: String
}

struct SkillPack: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var skillTitles: [String]
    var extraInstructions: [String]
}

struct PolicyConfig: Hashable, Codable {
    var allowRemote: Bool
    var requirePreflightPass: Bool
    var maxRequestCharacters: Int
    var blockedModes: [RunMode]
}

struct RunbookRule: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var triggerPattern: String
    var recommendation: String
}

enum CheckStatus: String, Hashable {
    case pass
    case warn
    case fail
}

struct PreflightCheck: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var status: CheckStatus
    var detail: String
}
