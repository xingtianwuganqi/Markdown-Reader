import SwiftUI

private enum WorkspaceMode: String, CaseIterable, Identifiable {
    case edit = "编辑", read = "阅读", split = "并排"
    var id: Self { self }
}

struct WorkspaceView: View {
    @Binding var document: MarkdownDocument
    let fileURL: URL?
    @State private var mode: WorkspaceMode = .read
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var query = ""
    @State private var showFind = false
    @State private var showSettings = false
    @State private var target: Int?
    @State private var blocks: [MarkdownBlock] = []
    @State private var parsedSource = ""
    @State private var statistics = DocumentStatistics("")
    @State private var selection: TextSelection?
    @AppStorage("readingFontSize") private var fontSize = 18.0
    @AppStorage("readingSerif") private var serif = false
    @AppStorage("appearance") private var appearance = "system"
    @FocusState private var editorFocused: Bool
    @FocusState private var findFocused: Bool
    private var title: String { fileURL?.deletingPathExtension().lastPathComponent ?? "未命名文档" }
    private var headings: [MarkdownBlock] { blocks.filter { if case .heading = $0.kind { true } else { false } } }
    private var matches: [MarkdownBlock] { query.isEmpty ? [] : blocks.filter { $0.text.localizedCaseInsensitiveContains(query) } }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    workspaceHeader(wide: geometry.size.width >= 760)
                    if showFind { findBar }
                    Divider()
                    if document.text.isEmpty && mode == .read {
                        emptyState
                    } else if mode == .edit {
                        editor
                    } else if mode == .split && geometry.size.width >= 760 {
                        HStack(spacing: 0) {
                            editor.frame(maxWidth: .infinity)
                            Divider()
                            reader.frame(maxWidth: .infinity)
                        }
                    } else {
                        reader
                    }
                    Divider()
                    statusBar
                }
                .onChange(of: geometry.size.width) { _, width in
                    if width < 760 && mode == .split { mode = .read }
                }
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { showFind.toggle() } label: { Label("查找", systemImage: "magnifyingglass") }
                        .keyboardShortcut("f", modifiers: .command)
                    if let fileURL { ShareLink(item: fileURL) { Label("分享文件", systemImage: "square.and.arrow.up") } }
                    Button { showSettings.toggle() } label: { Label("阅读设置", systemImage: "textformat.size") }
                }
            }
            .sheet(isPresented: $showSettings) { readingSettings }
        }
        .tint(Color.accentColor)
        .preferredColorScheme(appearance == "light" ? .light : appearance == "dark" ? .dark : nil)
        .onChange(of: showFind) { _, shown in findFocused = shown }
        .task(id: document.text) {
            let source = document.text
            // Avoid parsing on the UI actor; cancel stale results during typing.
            do { try await Task.sleep(for: .milliseconds(120)) } catch { return }
            let parsed = await Task.detached(priority: .userInitiated) { MarkdownParser.parse(source) }.value
            guard !Task.isCancelled else { return }
            blocks = parsed
            parsedSource = source
            statistics = DocumentStatistics(source)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "doc.richtext").font(.title2).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text("墨页").font(.headline)
                    Text("MARKDOWN READER").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.2).foregroundStyle(.secondary)
                }
            }.padding(22)
            Divider()
            List {
                Section("文档大纲") {
                    if headings.isEmpty {
                        Text("使用 # 添加标题，\n在这里快速浏览章节。").font(.callout).foregroundStyle(.secondary).padding(.vertical, 8)
                    }
                    ForEach(headings) { heading in
                        Button {
                            target = heading.id
                            if mode == .edit { mode = .read }
                            #if os(iOS)
                            columnVisibility = .detailOnly
                            #endif
                        } label: {
                            HStack(spacing: 8) {
                                if case .heading(let level) = heading.kind {
                                    Text(String(format: "%02d", headings.firstIndex(where: { $0.id == heading.id })! + 1))
                                        .font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
                                    Text(heading.text).font(.subheadline).lineLimit(2).padding(.leading, CGFloat(level - 1) * 8)
                                }
                            }.foregroundStyle(target == heading.id ? Color.accentColor : Color.primary)
                        }.buttonStyle(.plain).padding(.vertical, 5)
                    }
                }
            }.listStyle(.sidebar)
            VStack(alignment: .leading, spacing: 8) {
                Label("你的文字，留在你的文件里", systemImage: "externaldrive").font(.caption)
                Text("本地优先 · 原生体验 · 开源").font(.caption2).foregroundStyle(.tertiary)
            }.foregroundStyle(.secondary).padding(20)
        }
        .navigationTitle("文档")
    }

    private func workspaceHeader(wide: Bool) -> some View {
        HStack(spacing: 12) {
            if wide {
                Label("工作区", systemImage: "doc.text").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
            }
            Picker("显示模式", selection: $mode) {
                Text("阅读").tag(WorkspaceMode.read)
                Text("编辑").tag(WorkspaceMode.edit)
                if wide { Text("并排").tag(WorkspaceMode.split) }
            }.pickerStyle(.segmented).frame(maxWidth: 260)
            if !wide { Spacer(minLength: 0) }
            Button {
                mode = mode == .edit ? .read : .edit
            } label: { Image(systemName: mode == .edit ? "book" : "square.and.pencil") }
                .buttonStyle(.plain).help("切换编辑与阅读（⌘E）").accessibilityLabel("切换编辑与阅读")
                .keyboardShortcut("e", modifiers: .command)
        }.padding(.horizontal, 22).padding(.vertical, 13)
    }

    private var reader: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ReadingView(blocks: blocks, fontSize: fontSize, serif: serif, query: query) { line in
                    guard parsedSource == document.text else { return }
                    document.text = MarkdownParser.toggleTask(in: document.text, line: line)
                }
            }
            .onChange(of: target) { _, value in
                if let value { withAnimation { proxy.scrollTo(value, anchor: .top) } }
            }
            .onAppear { if let target { proxy.scrollTo(target, anchor: .top) } }
        }
    }

    private var editor: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    formatButton("标题", icon: "number", prefix: "## ", suffix: "", placeholder: "标题", line: true)
                    formatButton("加粗", icon: "bold", prefix: "**", suffix: "**", placeholder: "加粗文字")
                    formatButton("斜体", icon: "italic", prefix: "*", suffix: "*", placeholder: "斜体文字")
                    formatButton("任务", icon: "checklist", prefix: "- [ ] ", suffix: "", placeholder: "待办事项", line: true)
                    formatButton("链接", icon: "link", prefix: "[", suffix: "](https://example.com)", placeholder: "链接文字")
                    formatButton("代码", icon: "chevron.left.forwardslash.chevron.right", prefix: "\n```\n", suffix: "\n```\n", placeholder: "代码")
                }.padding(.horizontal, 18).padding(.vertical, 8)
            }
            TextEditor(text: $document.text, selection: $selection)
                .font(.system(size: 15, design: .monospaced))
                .lineSpacing(6)
                .scrollContentBackground(.hidden)
                .padding(16)
                .focused($editorFocused)
                .accessibilityLabel("Markdown 源码")
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif
        }.background(.primary.opacity(0.015))
    }

    private func formatButton(_ name: String, icon: String, prefix: String, suffix: String, placeholder: String, line: Bool = false) -> some View {
        Button { insert(prefix: prefix, suffix: suffix, placeholder: placeholder, line: line) } label: {
            Image(systemName: icon).frame(width: 30, height: 28)
        }.buttonStyle(.borderless).help(name).accessibilityLabel(name)
    }

    private func insert(prefix: String, suffix: String, placeholder: String, line: Bool) {
        var text = document.text
        var range = text.endIndex..<text.endIndex
        if let selection, case .selection(let selectedRange) = selection.indices { range = selectedRange }
        let selected = String(text[range])
        let needsNewline = line && range.lowerBound != text.startIndex && text[text.index(before: range.lowerBound)] != "\n"
        let insertion = (needsNewline ? "\n" : "") + prefix + (selected.isEmpty ? placeholder : selected) + suffix
        let offset = text.distance(from: text.startIndex, to: range.lowerBound)
        text.replaceSubrange(range, with: insertion)
        document.text = text
        let start = text.index(text.startIndex, offsetBy: offset)
        let end = text.index(start, offsetBy: insertion.count)
        selection = TextSelection(range: start..<end)
        editorFocused = true
    }

    private var findBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("查找文档内容", text: $query).textFieldStyle(.plain).focused($findFocused)
                .onSubmit { nextMatch() }
            Text("\(matches.count) 处").font(.caption).foregroundStyle(.secondary)
            Button("下一处", action: nextMatch).disabled(matches.isEmpty)
            Button { showFind = false; query = "" } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("关闭查找")
        }.padding(.horizontal, 22).padding(.bottom, 12)
    }

    private func nextMatch() {
        guard !matches.isEmpty else { return }
        mode = .read
        if let current = matches.firstIndex(where: { $0.id == target }) { target = matches[(current + 1) % matches.count].id }
        else { target = matches[0].id }
    }

    private var statusBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                Text("\(statistics.words) 字 / 词")
                Text("\(statistics.characters) 字符")
                Spacer()
                Text("约 \(statistics.readingMinutes) 分钟阅读")
                Circle().fill(Color.accentColor).frame(width: 5, height: 5)
                Text("Markdown")
            }
            HStack { Text("\(statistics.words) 字 / 词"); Spacer(); Text("Markdown") }
        }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 22).padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "leaf").font(.system(size: 42, weight: .light)).foregroundStyle(.tint)
            Text("留一页，给新的想法。").font(.title2.bold())
            Text("从一个标题开始，让文字慢慢生长。") .foregroundStyle(.secondary)
            Button("开始写作") { mode = .edit; editorFocused = true }.buttonStyle(.borderedProminent)
            Button("打开示例内容") { document.text = Self.sample }.buttonStyle(.plain).foregroundStyle(.tint)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(24)
    }

    private var readingSettings: some View {
        NavigationStack {
            Form {
                Section("阅读排版") {
                    LabeledContent("字号", value: "\(Int(fontSize)) pt")
                    Slider(value: $fontSize, in: 14...28, step: 1).accessibilityLabel("阅读字号")
                    Toggle("衬线字体", isOn: $serif)
                }
                Section("外观") {
                    Picker("主题", selection: $appearance) {
                        Text("跟随系统").tag("system")
                        Text("浅色").tag("light")
                        Text("深色").tag("dark")
                    }
                }
                Section {
                    Text("文字应该有自己的呼吸。\nMake room for your thoughts.")
                        .font(.system(size: fontSize, design: serif ? .serif : .default)).lineSpacing(8).padding(.vertical, 12)
                } header: { Text("预览") }
            }
            .formStyle(.grouped)
            .navigationTitle("阅读设置")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showSettings = false } } }
        }.frame(minWidth: 320, idealWidth: 420, minHeight: 420)
    }

    static let sample = """
    # 把想法，写成自己的形状。
    一页文字，一点专注。欢迎使用 **墨页**，一个轻盈、原生的 Markdown 阅读与写作空间。

    > 好的工具安静地退后，让你的想法站到前面。

    ## 从简单开始
    在上方切换 **编辑** 与 **阅读**。在 iPad 和 Mac 的宽窗口中，选择 **并排**，一边写作，一边看见文字的样子。

    - 文件保存在你选择的位置
    - 使用标题组织内容，在大纲中快速跳转
    - 调整字号和字体，找到舒服的阅读节奏

    ## 今天的小计划
    - [x] 留一点时间给自己
    - [ ] 记下一个值得保留的想法
    - [ ] 整理这一周的阅读笔记

    ## 让表达更丰富
    用 `行内代码` 标记细节，用代码块记录灵感。

    ```swift
    import SwiftUI

    Text("Hello, Markdown.")
        .font(.title)
    ```

    | 场景 | 适合的模式 |
    | --- | --- |
    | 沉浸阅读 | 阅读 |
    | 专注写作 | 编辑 |
    | 边写边看 | 并排 |

    ---
    你的下一篇故事，从这里开始。
    """
}
