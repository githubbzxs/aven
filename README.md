# Aven

Aven 是一个使用 SwiftUI 构建的个人被动收入看板：把多个量化策略、订阅出租和理财仓位的收益汇总到一个原生 iOS App 里，配合 Bark 推送告警和结算通知。

数据来自自建的汇总服务（tg-hub）提供的只读 JSON 接口；App 本身不保存账户凭据，也不做任何交易操作。

## 功能

- **Dashboard**：全部来源的累计收益曲线（1D / 7D / 30D / ALL），按住拖动查看任意时刻的真实累计值，带触觉反馈和从左向右的绘入动画
- **来源排行**：当前周期各来源的收益、笔数和占比条，Ondo 挂单另标“已实现 + 估算奖励”的预估区间
- **动态**：告警、盈亏阶梯、里程碑、日报晚报和逐笔成交，连续成交自动合并
- **来源详情**：单来源曲线、胜率、日均、分项、每日收益和逐笔记录；理财显示各仓位本金、现值、年化与风险状态，订阅出租显示额度和满额月收入估算
- **推送跳转**：Bark 通知点开经 `aven://source/<id>` 直接进入对应来源页
- **主币种**：美元或人民币，人民币按服务端实时汇率换算
- 前台每 30 秒自动刷新，冷启动先显示磁盘缓存

## 技术栈

- Swift 6、SwiftUI、Swift Charts
- iOS 26+（系统 Liquid Glass 底栏）
- Xcode 26+，无第三方依赖

## 接口

App 读取以下只读接口（`Authorization: Bearer <令牌>`）：

| 路径 | 内容 |
|---|---|
| `/v1/overview?range=` | 各来源在周期内的收益、今日收益、状态 |
| `/v1/series?src=&range=` | 累计曲线的原始事件，App 累加并取样 |
| `/v1/source?src=&range=` | 单来源的分项、每日、记录、仓位或额度 |
| `/v1/feed?limit=` | 推送过的通知与最近成交 |

`range` 取 `1d`、`7d`、`30d`、`all`，其中 `1d` 从当天 00:00（UTC+8）算起。

## 快速开始

1. 用 Xcode 打开 `Aven.xcodeproj`，在 Signing & Capabilities 选择开发团队。
2. 把接口令牌存进本机钥匙串（只需一次）：

   ```sh
   security add-generic-password -U -s aven/api-token -a aven -w '<令牌>'
   ```

3. 用 USB 连接 iPhone，运行：

   ```sh
   scripts/install.sh
   ```

   脚本会自动选中有线连接的真机，构建时把令牌注入 Info.plist（令牌不进仓库），并覆盖安装。也可以不注入令牌，装好后在 App 的 Settings 里填写。

## 项目结构

```text
Aven/
├── Aven.xcodeproj/
├── Config/Info.plist        # URL Scheme 与构建时注入的令牌占位
├── scripts/install.sh       # 真机构建与安装
└── Aven/
    ├── AvenApp.swift        # 入口
    ├── ContentView.swift    # 底栏、导航与 aven:// 跳转
    ├── Store.swift          # 接口、缓存、金额格式、钥匙串
    ├── Models.swift         # 接口数据模型
    ├── EarningsChart.swift  # 累计曲线、拖动选点、周期选择
    ├── DashboardView.swift  # 首页与动态
    ├── SourcesView.swift    # 来源列表与详情
    ├── SettingsView.swift   # 设置
    └── Theme.swift          # 颜色与通用组件
```

## 当前边界

- 只读展示，不录入收入、不下单、不改服务端数据。
- 使用免费开发者账号签名时，安装包约 7 天后需要重新签名安装。
- 推送依赖 Bark App；App 本身不申请推送权限。
