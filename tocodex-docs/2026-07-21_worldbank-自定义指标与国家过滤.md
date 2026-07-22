# 自定义添加国家/指标的 UI 功能

## 变更摘要
为 World Bank Data Explorer 添加了「自定义添加国家/指标」的 UI 交互功能。

## 改动文件

### translations/en.json
新增 6 个翻译键：`country_filter`, `custom_indicator`, `custom_indicator_id`, `custom_indicator_name`, `add_indicator`, `tab_custom`

### translations/zh.json
同上，新增 6 个中文翻译键

### templates/index.html
- 在国家 `<select>` 上方增加国家过滤 `<input>`
- 侧边栏新增标签页切换（"分类浏览" / "自定义"）
- 自定义标签页包含：指标 ID 输入框 + 名称输入框 + 添加按钮 + 已有自定义指标列表

### static/style.css
新增样式：
- `.sidebar-tabs` / `.sidebar-tab` — 标签页切换按钮
- `.custom-indicator-form` — 自定义指标表单
- `.custom-item` / `.ci-name` / `.ci-id` / `.ci-remove` — 自定义指标列表行
- `#country-filter` — 国家过滤输入框

### static/app.js
新增功能：
- `filterCountries(query)` — 实时过滤国家列表（按名称/ISO3/ISO2 匹配）
- `getCustomIndicators()` / `saveCustomIndicators()` — localStorage 持久化
- `initCustomIndicators()` / `renderCustomList()` — 渲染自定义指标列表
- `addCustomIndicator()` — 添加并去重
- `removeCustomIndicator(idx)` — 逐个删除
- `selectCustomIndicator(id, name)` — 选中后填入指标下拉框并加载数据
- `switchSidebarTab(tab)` — 预设/自定义标签切换
- `selectIndicatorFromSearch()` — 搜索时也检查自定义指标

### handlers.v
`handle_index()` 中新增 6 个 `@xxx` 模板变量替换
