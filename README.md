# Aven

Aven 是一个使用 SwiftUI 构建的个人收益看板，用于集中展示多个收入来源、总收益走势与不同时间范围的表现。

当前版本专注于原生 iOS 交互与图表体验，全部数据均为本地生成的 mock 数据，不包含真实账户、收入同步或后端服务。

## 功能

- 汇总多个收入来源的总收益与贡献比例
- 展示 `24H`、`7D`、`30D` 和 `1Y` 收益曲线
- 分钟级 mock 数据与高密度图表降采样
- Swift Charts 原生 Monotone cubic 曲线
- 拖动选点、同步收益变化与触觉反馈
- SwiftUI 原生 `TabView` 与系统 Liquid Glass

## 技术栈

- Swift 6
- SwiftUI
- Swift Charts
- iOS 26+
- Xcode 26+

## 快速开始

1. 克隆仓库并进入项目目录。
2. 使用 Xcode 打开 `Aven.xcodeproj`。
3. 在 Signing & Capabilities 中选择可用的开发团队。
4. 选择支持 iOS 26 或更高版本的目标设备并构建。

```sh
open Aven.xcodeproj
```

## 项目结构

```text
Aven/
├── Aven.xcodeproj/       # Xcode 工程
└── Aven/
    ├── AvenApp.swift     # App 入口
    ├── ContentView.swift # 一级导航
    ├── Pages.swift       # Dashboard、Sources 与 Settings
    └── Assets.xcassets/  # 颜色与 App 图标
```

## 当前边界

- 数据仅用于界面与交互演示。
- 暂未实现真实收入录入、账号体系、云同步、订阅或后端。
- 图表数据由确定性的本地算法生成，因此每次构建具有一致的演示走势。
