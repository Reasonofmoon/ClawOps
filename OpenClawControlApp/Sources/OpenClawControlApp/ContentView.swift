import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var vm: AppViewModel

    private let thinkingLevels = ["off", "minimal", "low", "medium", "high"]

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                HSplitView {
                    leftPanel
                        .frame(minWidth: 300, idealWidth: 340, maxWidth: 380)

                    centerPanel
                        .frame(minWidth: 500, idealWidth: 680)

                    rightPanel
                        .frame(minWidth: 340, idealWidth: 430, maxWidth: 560)
                }
                .padding(DS.space16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 980, minHeight: 640)
        .task {
            vm.bootstrapAndLoad()
        }
    }

    private var topBar: some View {
        HStack(spacing: DS.space12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("OpenClaw Control")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DS.textStrong)
                Text("Profiles • Skill Packs • Policies • Runbooks")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(DS.textMuted)
            }

            Spacer()

            statusPill
        }
        .padding(.horizontal, DS.space16)
        .padding(.vertical, DS.space12)
        .background(DS.panel)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DS.border).frame(height: 1)
        }
    }

    private var leftPanel: some View {
        ScrollView {
            VStack(spacing: DS.space12) {
                panelCard(title: "프로필") {
                    VStack(spacing: DS.space8) {
                        Picker("", selection: $vm.selectedProfileID) {
                            ForEach(vm.profiles, id: \.id) { profile in
                                Text(profile.name).tag(profile.id)
                            }
                        }
                        .labelsHidden()

                        HStack(spacing: DS.space8) {
                            actionButton("적용", variant: .secondary) { vm.applySelectedProfile() }
                            actionButton("현재값 저장", variant: .ghost) { vm.saveCurrentToSelectedProfile() }
                        }
                    }
                }

                panelCard(title: "스킬팩") {
                    VStack(spacing: DS.space8) {
                        Picker("", selection: $vm.selectedSkillPackID) {
                            ForEach(vm.skillPacks, id: \.id) { pack in
                                Text(pack.name).tag(pack.id)
                            }
                        }
                        .labelsHidden()

                        HStack(spacing: DS.space8) {
                            actionButton("적용", variant: .secondary) { vm.applySelectedSkillPack() }
                            actionButton("현재값 저장", variant: .ghost) { vm.saveCurrentToSelectedSkillPack() }
                        }
                    }
                }

                panelCard(title: "작업 설정") {
                    VStack(spacing: DS.space10) {
                        labeledRow("모드") {
                            Picker("", selection: $vm.selectedMode) {
                                ForEach(RunMode.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .labelsHidden()
                        }

                        labeledRow("Thinking") {
                            Picker("", selection: $vm.thinkingLevel) {
                                ForEach(thinkingLevels, id: \.self) { level in
                                    Text(level).tag(level)
                                }
                            }
                            .labelsHidden()
                        }

                        Toggle("Remote", isOn: $vm.useRemote)
                        Toggle("출력 파일 저장", isOn: $vm.saveOutputToFile)
                    }
                }

                panelCard(title: "정책") {
                    VStack(alignment: .leading, spacing: DS.space8) {
                        Toggle("Remote 허용", isOn: $vm.policy.allowRemote)
                        Toggle("Preflight 실패 시 실행 차단", isOn: $vm.policy.requirePreflightPass)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("요청 길이 제한: \(vm.policy.maxRequestCharacters)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(DS.textMuted)
                            Stepper("", value: $vm.policy.maxRequestCharacters, in: 500...20000, step: 250)
                                .labelsHidden()
                        }

                        actionButton("정책 저장", variant: .secondary) { vm.savePolicy() }
                    }
                }

                panelCard(title: "Preflight") {
                    VStack(alignment: .leading, spacing: DS.space8) {
                        actionButton("점검 실행", variant: .secondary) { vm.runPreflight() }

                        ForEach(vm.preflightChecks) { check in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(color(for: check.status))
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 4)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(check.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(DS.textStrong)
                                    Text(check.detail)
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundStyle(DS.textMuted)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var centerPanel: some View {
        VStack(spacing: DS.space12) {
            panelCard(title: "프리셋") {
                HStack(spacing: DS.space8) {
                    Picker("", selection: $vm.selectedPresetName) {
                        ForEach(vm.presets, id: \.name) { preset in
                            Text(preset.displayLabel).tag(preset.name)
                        }
                    }
                    .labelsHidden()

                    actionButton("불러오기", variant: .secondary) { vm.applySelectedPresetToRequest() }
                        .fixedSize()
                    actionButton("바로 실행", variant: .primary) { vm.runQuickPreset() }
                        .fixedSize()
                }
            }

            panelCard(title: "스킬 지시") {
                HStack(spacing: DS.space10) {
                    ForEach(vm.skillSnippets) { skill in
                        let isOn = Binding<Bool>(
                            get: { vm.selectedSkillTitles.contains(skill.title) },
                            set: { enabled in
                                if enabled { vm.selectedSkillTitles.insert(skill.title) }
                                else { vm.selectedSkillTitles.remove(skill.title) }
                            }
                        )
                        Toggle(skill.title, isOn: isOn)
                            .toggleStyle(.switch)
                    }
                }
            }

            panelCard(title: "요청") {
                VStack(spacing: DS.space8) {
                    TextEditor(text: $vm.requestText)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundStyle(DS.textStrong)
                        .scrollContentBackground(.hidden)
                        .padding(DS.space8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(DS.editor)
                        .clipShape(RoundedRectangle(cornerRadius: DS.radius10))

                    HStack(spacing: DS.space8) {
                        actionButton("클립보드 붙여넣기", variant: .secondary) {
                            vm.pasteRequestFromClipboard()
                        }
                        actionButton("요청 비우기", variant: .ghost) {
                            vm.requestText = ""
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: DS.space8) {
                actionButton("상태 체크", variant: .secondary) { vm.runCheck() }
                actionButton("실행", variant: .primary) { vm.runTask() }
                    .keyboardShortcut(.return, modifiers: [.command])
                actionButton("중단", variant: .secondary) { vm.stop() }
                actionButton("로그 지우기", variant: .ghost) { vm.clearOutput() }
            }
        }
    }

    private var rightPanel: some View {
        VStack(spacing: DS.space12) {
            if !vm.lastRunbookRecommendation.isEmpty {
                panelCard(title: "런북 추천") {
                    Text(vm.lastRunbookRecommendation)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            panelCard(title: "실행 로그") {
                ScrollView {
                    Text(vm.outputText.isEmpty ? "로그가 없습니다." : vm.outputText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(DS.textSubtle)
                        .textSelection(.enabled)
                        .padding(DS.space8)
                }
                .background(DS.editor)
                .clipShape(RoundedRectangle(cornerRadius: DS.radius10))
                .frame(maxHeight: .infinity)
            }
        }
    }

    private var statusPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(vm.isRunning ? DS.accent : DS.textMuted)
                .frame(width: 8, height: 8)
            Text(vm.isRunning ? "실행 중" : "대기")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(vm.isRunning ? DS.accent : DS.textMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(DS.subtle)
        .clipShape(RoundedRectangle(cornerRadius: DS.radius10))
    }

    private func panelCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.space10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.textStrong)
            content()
        }
        .padding(DS.space12)
        .background(DS.panel)
        .clipShape(RoundedRectangle(cornerRadius: DS.radius12))
        .overlay {
            RoundedRectangle(cornerRadius: DS.radius12)
                .stroke(DS.border, lineWidth: 1)
        }
    }

    private func labeledRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DS.textMuted)
            Spacer()
            content().frame(maxWidth: 170)
        }
    }

    private func actionButton(_ title: String, variant: DS.ButtonVariant, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(DS.ButtonStyle(variant: variant))
    }

    private func color(for status: CheckStatus) -> Color {
        switch status {
        case .pass: return DS.success
        case .warn: return DS.warning
        case .fail: return DS.error
        }
    }
}

private enum DS {
    static let bg = Color(red: 0.06, green: 0.07, blue: 0.10)
    static let panel = Color(red: 0.10, green: 0.11, blue: 0.15)
    static let subtle = Color(red: 0.12, green: 0.13, blue: 0.18)
    static let editor = Color(red: 0.08, green: 0.09, blue: 0.13)
    static let border = Color.white.opacity(0.09)

    static let accent = Color(red: 0.34, green: 0.53, blue: 1.0)
    static let accentPressed = Color(red: 0.27, green: 0.45, blue: 0.95)

    static let success = Color(red: 0.35, green: 0.83, blue: 0.55)
    static let warning = Color(red: 0.98, green: 0.75, blue: 0.34)
    static let error = Color(red: 0.95, green: 0.40, blue: 0.42)

    static let textStrong = Color.white.opacity(0.96)
    static let textSubtle = Color.white.opacity(0.78)
    static let textMuted = Color.white.opacity(0.58)

    static let space8: CGFloat = 8
    static let space10: CGFloat = 10
    static let space12: CGFloat = 12
    static let space16: CGFloat = 16
    static let radius10: CGFloat = 10
    static let radius12: CGFloat = 12

    enum ButtonVariant {
        case primary
        case secondary
        case ghost
    }

    struct ButtonStyle: SwiftUI.ButtonStyle {
        let variant: ButtonVariant

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(background(configuration.isPressed))
                .clipShape(RoundedRectangle(cornerRadius: radius10))
                .overlay {
                    RoundedRectangle(cornerRadius: radius10)
                        .stroke(borderColor, lineWidth: 1)
                }
        }

        private var foreground: Color {
            switch variant {
            case .primary: return .white
            case .secondary: return textStrong
            case .ghost: return textMuted
            }
        }

        private var borderColor: Color {
            switch variant {
            case .primary: return accent.opacity(0.45)
            case .secondary: return border
            case .ghost: return border.opacity(0.6)
            }
        }

        private func background(_ pressed: Bool) -> Color {
            switch variant {
            case .primary: return pressed ? accentPressed : accent
            case .secondary: return pressed ? subtle.opacity(0.9) : subtle
            case .ghost: return pressed ? subtle.opacity(0.75) : .clear
            }
        }
    }
}
