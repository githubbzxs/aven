import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(Store.self) private var store
    @State private var tokenDraft = ""
    @State private var editingToken = false
    @State private var pingResult: String?
    @State private var pinging = false

    var body: some View {
        @Bindable var store = store

        PageScroll {
            PageTitle(title: "Settings")

            SectionHeader("显示")
            row("主币种") {
                Picker("主币种", selection: $store.currency) {
                    ForEach(DisplayCurrency.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            Hairline()
            row("汇率") {
                Text(store.rate > 0 ? "1 U ≈ ¥" + store.rate.formatted(.number.precision(.fractionLength(4))) : "—")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            SectionHeader("数据")
            row("接口") {
                TextField(Store.defaultBase, text: $store.baseURL)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .foregroundStyle(.secondary)
            }
            Hairline()
            row("令牌") {
                if editingToken {
                    SecureField("粘贴令牌", text: $tokenDraft)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit(saveToken)
                    Button("保存", action: saveToken)
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text(store.isConfigured ? "已配置" : "未配置")
                        .foregroundStyle(store.isConfigured ? AnyShapeStyle(.secondary) : AnyShapeStyle(AppTheme.warning))
                    Button(store.isConfigured ? "更换" : "填写") {
                        tokenDraft = ""
                        editingToken = true
                    }
                    .foregroundStyle(Color.accentColor)
                }
            }
            Hairline()
            row("连接") {
                if pinging {
                    ProgressView().controlSize(.small)
                } else if let pingResult {
                    Text(pingResult)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Button("测试") { Task { await ping() } }
                    .foregroundStyle(Color.accentColor)
                    .disabled(pinging)
            }
            Hairline()
            row("上次更新") {
                Text(store.lastUpdated?.feedText ?? "—")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            SectionHeader("通知")
            VStack(alignment: .leading, spacing: 10) {
                Text("通知由自建 Bark 推送，点开直接进 Aven 对应的来源页。")
                Text("⚠️ 告警用时效性通知，会穿透专注模式；停机、清算、熔断这类严重告警用重要警报，静音也会响。结算、阶梯、里程碑和日报晚报是普通通知。")
                Button {
                    UIPasteboard.general.string = "https://bark.0xpsyche.me"
                } label: {
                    Label("复制 Bark 服务器地址", systemImage: "doc.on.doc")
                }
                .foregroundStyle(Color.accentColor)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.vertical, 12)

            SectionHeader("关于")
            row("版本") {
                Text(appVersion)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Hairline()
            VStack(alignment: .leading, spacing: 6) {
                Text("数据来自 tg-hub：各策略账本只读汇总，金额按 U 记账（U 按 1:1 美元），人民币按实时汇率换算。1D 从今天 00:00（UTC+8）算起。")
            }
            .font(.footnote)
            .foregroundStyle(.tertiary)
            .padding(.vertical, 12)
        }
        .accessibilityIdentifier("screen.settings")
    }

    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer(minLength: 12)
            content()
        }
        .font(.subheadline)
        .frame(minHeight: 48)
    }

    private func saveToken() {
        store.updateToken(tokenDraft)
        editingToken = false
        Task { await ping() }
    }

    private func ping() async {
        pinging = true
        defer { pinging = false }
        do {
            let ms = try await store.ping()
            pingResult = "正常 · \(ms) ms"
            await store.refreshMain(range: .day)
        } catch {
            pingResult = error.localizedDescription
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }
}
