# 架构设计文档

## 项目概览

World Bank Data Explorer 是一个用 V 语言编写的中英文双语世界银行数据展示 Web 应用。采用 **Backend-rendered shell + AJAX data** 模式：页面骨架由后端渲染（含语言感知的导航和 UI 标签），数据通过前端 `fetch()` 从 JSON API 异步获取。

## 架构分层

```
┌─────────────────────────────────────────────────┐
│                  浏览器 (Browser)                 │
│   HTML + CSS + JavaScript (Chart.js)            │
│   ┌──────────┐ ┌──────────┐ ┌───────────────┐  │
│   │  搜索/排序  │ │ 表格渲染   │ │  图表 (Chart.js)│  │
│   └──────────┘ └──────────┘ └───────────────┘  │
└───────────────────┬─────────────────────────────┘
                    │ HTTP REST
┌───────────────────▼─────────────────────────────┐
│               V 后端 (net.http.Server)            │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐  │
│  │ main.v   │  │handlers.v│  │  wbapi.v     │  │
│  │ 入口+路由 │─▶│ 路由处理   │─▶│ WB API 客户端  │  │
│  └──────────┘  └──────────┘  └──────┬───────┘  │
│       │               │              │          │
│  ┌────▼────┐    ┌─────▼─────┐  ┌────▼───────┐  │
│  │models.v │    │ translations│  │ SQLite 缓存 │  │
│  │ 数据模型  │    │  en/zh.json │  │  data/*.db  │  │
│  └─────────┘    └───────────┘  └────────────┘  │
└─────────────────────────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────┐
│           世界银行公开 API (REST)                  │
│    https://api.worldbank.org/v2/...              │
└─────────────────────────────────────────────────┘
```

## 组件说明

### 1. 后端组件

#### App 结构体 (`main.v`)

```v
pub struct App {
pub:
    db            sqlite.DB                    // SQLite 数据库连接
    translations  map[string]map[string]string  // i18n 翻译映射
    template_html string                       // 预加载的 HTML 模板
    started_at    i64                          // 启动时间戳
}
```

实现 `http.Handler` 接口的 `handle()` 方法，作为路由分发器。

#### 路由分发 (`handlers.v`)

所有 HTTP 请求处理函数集中在 `handlers.v` 中，包括：
- **页面渲染**: `handle_index()` — 模板变量替换
- **语言切换**: `handle_set_lang()` — 设置 Cookie
- **JSON API**: `handle_api_categories()`, `handle_api_countries()`, `handle_api_data()`, `handle_api_search()`
- **静态文件**: `serve_static()` — 从 `static/` 目录读取

#### WB API 客户端 (`wbapi.v`)

封装世界银行 API 的调用逻辑：
- `wb_fetch(url)` — 通用 HTTP GET 请求
- `wb_parse_envelope(body)` — 解析 WB API 的 `[meta, data...]` 响应格式
- `fetch_countries()` — 带 SQLite 缓存的国家列表获取
- `fetch_indicator_data()` — 带 SQLite 缓存的指标数据获取（含排序）
- `search_indicators()` — 本地指标搜索

#### 数据模型 (`models.v`)

定义了 6 个结构体和 2 个常量：
- `Country`, `Indicator`, `DataPoint`, `DataRecord`, `Category`, `SearchResult`
- `cache_ttl_ms` — 缓存有效期 300 秒 (5 分钟)
- `default_categories` — 9 个类别共约 50 个预定义指标

### 2. 前端组件

#### 主页面 (`templates/index.html`)

单页应用模板，包含：
- 顶部导航栏：标题 + 语言选择器
- 左侧面板：类别导航 + 搜索框
- 右侧面板：国家选择 + 指标选择 + 年份范围 + 加载按钮
- 数据展示区域：表格 + 图表（Chart.js CDN）

模板使用 `@variable` 占位符，后端在 `handle_index()` 中逐一替换。

#### 前端交互 (`static/app.js`)

主要功能模块：

| 模块 | 函数 | 职责 |
|------|------|------|
| 初始化 | `initApp()` | 页面加载完成后的初始化 |
| 类别加载 | `loadCategories()` | 从 `/api/categories` 加载类别树 |
| 国家加载 | `loadCountries()` | 从 `/api/countries` 加载国家选项 |
| 数据加载 | `loadData()` | 从 `/api/data` 获取数据并调用渲染函数 |
| 表格渲染 | `renderTable()` | 渲染可排序数据表格 |
| 图表渲染 | `renderChart()` | 使用 Chart.js 绘制折线图/柱状图 |
| 搜索 | `searchIndicators()` | 从 `/api/search` 获取搜索结果 |
| 排序 | `sortData()` | 按年份/数值升序/降序排列数据 |
| CSV 导出 | `exportCSV()` | 将数据导出为 CSV 文件下载 |
| 语言切换 | — | 通过 `/set-lang` 端点切换语言 |

#### 样式 (`static/style.css`)

响应式设计，适配桌面和移动端：
- CSS 变量定义主题色（深蓝色系）
- Flexbox 布局
- 表格斑马条纹
- 按钮悬浮效果

### 3. i18n 国际化

使用 `vlib/i18n` 模块：

```v
// 加载翻译（启动时）
translations := i18n.load_tr_map_from_dir('translations')

// 获取翻译（运行时）
i18n.tr_from_map(app.translations, lang, 'app_title')
```

**翻译文件结构**:
```json
{
  "app_title": "World Bank Data Explorer",
  "nav_home": "Home",
  "search": "Search",
  ...
}
```

**数据语言**: 世界银行 API 本身支持 `lang` 参数，国家名和部分指标名可以多语言返回。

### 4. 缓存策略

使用 SQLite 作为缓存存储：

```
表结构: cache (key TEXT PK, value TEXT, created_at INTEGER)
缓存键: countries_{lang} | data_{indicator}_{country}_{start}_{end}_{lang}
TTL: 300000ms (5分钟)
```

缓存流程：
```
请求 → cache_get(key)
  ├─ 命中且未过期 → 直接返回
  └─ 未命中/过期 → 请求 WB API → cache_set(key, value) → 返回
```

## 路由表

| 方法 | 路径 | Handler | 返回类型 | 说明 |
|------|------|---------|----------|------|
| GET | `/` | `handle_index` | text/html | 首页 |
| GET | `/set-lang` | `handle_set_lang` | 302 | 切语言 |
| GET | `/api/categories` | `handle_api_categories` | application/json | 类别列表 |
| GET | `/api/countries` | `handle_api_countries` | application/json | 国家列表 |
| GET | `/api/data` | `handle_api_data` | application/json | 指标数据 |
| GET | `/api/search` | `handle_api_search` | application/json | 搜索指标 |
| GET | `/*.css` | `serve_static` | text/css | CSS |
| GET | `/*.js` | `serve_static` | application/javascript | JS |
| 其他 | — | 404 | text/plain | 未找到 |

## 数据流示例

以"查看中国 GDP 趋势"为例：

1. 浏览器请求 `GET /`，后端返回含所有 UI 标签的完整 HTML
2. JS 自动请求 `GET /api/countries`，获取国家列表填充 `<select>` 框
3. 用户选择"China"、指标"GDP"、年份"2000-2023"
4. 点击"加载数据" → JS 请求 `GET /api/data?indicator=NY.GDP.MKTP.CD&country=CHN&year_start=2000&year_end=2023`
5. 后端检查 SQLite 缓存：
   - 命中 → 直接返回缓存的 JSON
   - 未命中 → 请求 `https://api.worldbank.org/v2/country/CHN/indicator/NY.GDP.MKTP.CD?format=json&per_page=200&date=2000:2023`
   - 解析结果 → 存入 SQLite → 返回 JSON
6. JS 接收 JSON → `renderTable(points)` 渲染可排序表格 → `renderChart(points, 'line')` 绘制折线图

## 预定义指标 (9 大类别，约 50 个指标)

| 类别 | 指标数 | 关键指标 |
|------|--------|---------|
| 经济 | 7 | GDP、GDP 增长、GDP per capita、通胀、失业率、GNI per capita、储蓄率 |
| 人口 | 8 | 总人口、增长率、出生率、死亡率、城市人口、预期寿命(总/男/女) |
| 健康 | 5 | 婴儿死亡率、医疗支出(%GDP)、人均医疗支出、免疫率、营养不良率 |
| 教育 | 5 | 小学/中学/大学入学率、识字率、小学完成率 |
| 环境 | 5 | CO₂排放(总量/人均)、森林面积、电力消耗、CO₂强度 |
| 科技 | 5 | 互联网使用率、手机普及率、科技论文、研发支出、宽带订阅 |
| 贸易 | 4 | 出口额、进口额、贸易占GDP、ICT服务出口 |
| 债务 | 4 | 外债总额、利息支出、政府债务(%GDP)、FDI |
| 贫困 | 5 | 贫困率(2.15美元/天)、GINI系数、收入份额(最高/最低)、GNI per capita(PPP) |

## 环境要求

| 依赖 | 版本 | 说明 |
|------|------|------|
| V 编译器 | ≥ 0.5.2 | 推荐使用最新稳定版 |
| SQLite | 内置 | V 标准库自带 |
| 网络 | 需访问 `api.worldbank.org` | 代理环境需配置 HTTP_PROXY |

## 已知限制

1. **Windows 防火墙**: 首次运行可能被 Windows Defender 防火墙拦截，需手动允许
2. **WB API 速率**: 世界银行 API 有使用限制，建议通过缓存减少请求次数
3. **搜索范围**: 当前为本地搜索（仅匹配预定义指标名称），未对接 WB 搜索 API
4. **线程模型**: `net.http.Server` 为同步单线程模型，适合低并发场景
