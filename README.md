# 墨页 · Markdown Reader

一个使用 SwiftUI 开发的原生 Markdown 文件编辑与阅读应用，面向 iPhone、iPad 和 Mac。当前为可构建的 **v0.1 开发版**。

## 功能

- 系统文档新建、打开与保存，支持 `.md`、`.markdown`、`.mdown` 和纯文本读取
- 阅读、源码编辑、大屏并排预览
- 文档大纲、内容块查找与跳转
- 选区格式工具条：标题、加粗、斜体、任务、链接、代码
- 原生标题、引用、列表、任务、代码和简单表格渲染
- 阅读字号、衬线字体和深浅色设置
- 中文／英文混合文档统计、阅读时间估算
- 无第三方依赖、无 WebView、无账号

## 运行

使用 Xcode 16 或更新版本（本次验证使用 Xcode 26.6）。最低系统为 iOS / iPadOS 18 和 macOS 15。

1. 打开 `MarkdownReader.xcodeproj`。
2. 选择 `MarkdownReader` scheme 和 Mac 或 iOS 设备。
3. 真机运行时，在 Signing & Capabilities 选择自己的开发团队，并设置唯一 Bundle ID。
4. 运行后打开 Markdown 文件，或新建文档后点击「打开示例内容」。

Mac 快捷键：`⌘E` 切换编辑／阅读，`⌘F` 查找；打开、新建和保存使用系统文档菜单。

## 验证

```sh
swift test
xcodebuild -project MarkdownReader.xcodeproj -scheme MarkdownReader \
  -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project MarkdownReader.xcodeproj -scheme MarkdownReader \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

受限环境可将 Swift 模块缓存和构建目录指向可写位置：

```sh
CLANG_MODULE_CACHE_PATH=/tmp/markdown-reader-module-cache \
  swift test --disable-sandbox --scratch-path /tmp/markdown-reader-tests
```

## 项目结构

- `MarkdownReader/MarkdownReaderApp.swift`：应用入口、文件格式和文档读写。
- `MarkdownReader/Core`：不依赖 UI 的 Markdown 块解析与统计。
- `MarkdownReader/Views`：自适应工作区、原生阅读器。
- `Tests/MarkdownCoreTests`：标题、代码围栏、表格、任务写回、换行和统计测试。
- [产品设计](docs/PRODUCT.md)：定位、视觉规范、交互和迭代范围。
- [验证记录](docs/VALIDATION.md)：已验证内容与发布前待验证项。

Xcode 工程已提交到目录，直接打开即可；新增源码文件后可以运行 `python3 scripts/generate_project.py` 重新生成工程。脚本会覆盖工程配置，自定义签名配置前请留意这一点。

## 当前限制

实现的是常用 Markdown 子集；尚不完整兼容 CommonMark / GFM。图片、嵌套列表、数学公式、HTML、Mermaid、PDF 导出、语法着色和滚动联动尚未实现。查找按块计数，并跳转到阅读区；不支持替换。暂无正式应用图标。

系统文件提供器允许用户选择 iCloud 等位置，但云盘同步与冲突行为尚未经过专项验证。当前不应视为已完成 App Store 发布验收的版本。

## 许可证

保留原项目 [Apache License 2.0](LICENSE)。
