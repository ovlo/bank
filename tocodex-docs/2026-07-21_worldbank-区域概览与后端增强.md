# 后端增强：区域概览看板 + WB API 搜索 + 国家组织

## 变更摘要

### 1. 🌍 主页全球与区域概览看板
- **`models.v`**: 新增 `RegionAggregate`、`WorldSummaryItem`、`RegionSummary`、`OverviewIndicator` 结构体；定义了 `overview_indicators`（8 个核心指标）和 `important_regions`（10 个区域/组织）
- **`wbapi.v`**: 新增 `fetch_region_latest_values`（单区域批量取最新值）、`fetch_all_regions_overview`（所有区域概览，带缓存）
- **`handlers.v`**: 新增 `GET /api/regions-overview` 端点
- **`main.v`**: 新增路由分发
- **`templates/index.html`**: 概览看板区域，含区域标签页、指标卡片、对比图
- **`static/app.js`**: 概览初始化、区域标签切换、指标卡片渲染（自动格式化大数值）、区域对比柱状图（Chart.js）
- **`static/style.css`**: 概览区域完整样式（卡片、标签、分割线、mini spinner）
- **翻译文件**: `overview_title`、`overview_subtitle`、`overview_chart_title`

### 2. 🌐 世界 (WLD) 作为首要国家
- **`fetch_countries`**: 注入 WLD 至国家列表首位，名称显示 "🌍 世界 (World)" / "🌍 World"
- **`ensure_world_first`**: 将 WLD 放在首位，过滤掉 API 返回的 WLD 重复项
- **`fetch_indicator_data`**: 自动将 `WLD` 映射为 `1W`（WB API 实际代码）
- **国家预选**: 前端预选国家包含 WLD

### 3. 🏢 重要国家组织/地区聚合
- 10 个聚合区域：World、EU、OECD、E.Asia、Eur.Cent.、L.America、M.East、N.America、S.Asia、Sub-Sah.Africa
- 每个区域自动加载 8 个核心指标的最新数据，带 SQLite 缓存
- 主页可通过区域标签切换查看不同区域概览

### 4. 🔍 WB API 搜索增强
- **`search_indicators_wb`**: 先本地搜索，再通过 WB API `/indicator?search=` 补充
- 自动去重（本地结果优先），API 搜索失败时回退到纯本地结果

## 修改文件
| 文件 | 改动 |
|------|------|
| models.v | +4 结构体 +2 常量数组（overview_indicators, important_regions） |
| wbapi.v | +fetch_region_latest_values +fetch_all_regions_overview +search_indicators_wb +WLD 映射 |
| handlers.v | +/api/regions-overview 路由 +search_indicators_local 回退函数 |
| main.v | +/api/regions-overview 路由分发 |
| templates/index.html | +概览看板 HTML 区域 |
| static/app.js | +概览初始化 +区域标签 +指标卡片 +对比图 |
| static/style.css | +概览区域完整样式 |
| translations/en.json | +3 翻译键 |
| translations/zh.json | +3 翻译键 |
