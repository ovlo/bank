---
created: 2026-07-21T07:36:12.555Z
status: active
---
# 🌍 World Bank Data Explorer — 架构设计方案

## 项目概述

用 V 语言的 veb 框架构建一个**中英文可切换**的世界银行数据展示 Web 应用，支持搜索、分类浏览、排序、筛选、趋势图展示。数据来自世界银行公开 API。

---

## 📁 项目结构

```
show_worldbank/
├── v.mod                    # 模块定义
├── main.v                   # 入口
├── app.v                    # App/WebCtx 定义 + 路由处理
├── wbapi.v                  # World Bank API 客户端（代理/缓存）
├── models.v                 # 数据模型
├── translations/
│   ├── en.json              # 英文本地化
│   └── zh.json              # 中文本地化
├── templates/
│   └── index.html           # 主页面模板
└── static/
    ├── style.css            # 样式
    └── app.js               # 前端交互（搜索/排序/图表）
```

---

## 🏗 架构设计

### 后端（Veb + V）

| 组件 | 职责 |
|------|------|
| `App` struct | 全局状态：缓存、配置 |
| `WebCtx` struct | 嵌入 `veb.Context`，携带 `lang` 字段 |
| `before_request` | 从 cookie/query 读取语言偏好 |
| 路由处理 | 页面渲染 + JSON API |
| `wbapi.v` | 代理世界银行 REST API，内存缓存结果 |
| `models.v` | Country / Indicator / DataRecord 等结构体 |

### 前端（纯 HTML + JS）

采用 **Backend-rendered shell + AJAX data** 模式：
- 页面骨架由 V 模板渲染（含语言感知的导航）
- 数据通过 `fetch('/api/...')` 从后端 JSON API 获取
- 前端负责搜索、排序、表格渲染、图表（Chart.js CDN）

### 数据流

```
浏览器 ──GET /──→ Veb ──→ index.html（含类别导航）
浏览器 ──GET /api/categories──→ JSON（预定义类别+指标列表）
浏览器 ──GET /api/indicators?category=X──→ Veb ──→ WB API（带缓存）
浏览器 ──GET /api/data?indicator=X&country=Y&years=Z──→ Veb ──→ WB API
浏览器 ──GET /api/countries──→ Veb ──→ WB API（带缓存）
浏览器 ──GET /api/search?q=X──→ Veb ──→ WB API（搜索指标）
```

---

## 🛣 路由设计

| 方法 | 路径 | 功能 |
|------|------|------|
| GET | `/` | 首页（主页面） |
| GET | `/set-lang?lang=en\|zh` | 切换语言（设置 cookie） |
| GET | `/api/categories` | 获取所有类别及指标列表 |
| GET | `/api/indicators` | 按类别获取指标 |
| GET | `/api/countries` | 获取国家列表 |
| GET | `/api/data` | 获取指标数据（参数：indicator, country, year_start, year_end） |
| GET | `/api/search` | 搜索指标（参数：q） |
| 静态 | `/css/style.css`, `/js/app.js` | 静态文件 |

---

## 📊 数据类别（覆盖用户所有需求）

| 类别 | 中文名 | 示例指标 |
|------|--------|---------|
| `economy` | 经济 | GDP、GDP per capita、通胀、失业率、GDP增长 |
| `population` | 人口 | 总人口、增长率、出生率、死亡率、城市人口 |
| `health` | 健康 | 预期寿命、婴儿死亡率、医疗支出 |
| `education` | 教育 | 入学率（小/中/高）、成人识字率 |
| `environment` | 环境 | CO2排放、森林面积、电力消耗 |
| `technology` | 科技 | 互联网使用率、手机普及率、科技论文 |
| `trade` | 贸易 | 进出口额、贸易占GDP比重 |
| `debt` | 债务 | 外债总额、利息支出 |
| `poverty` | 贫困 | 贫困率、GINI系数 |

---

## 🌐 i18n 策略

使用 `vlib/i18n` 模块加载 `translations/*.json` 文件：
- `en.json`：英文 → 默认
- `zh.json`：中文 → 用户切换

翻译覆盖：UI标签、类别名、导航、提示信息。**数据本身（国家名、指标名）由世界银行 API 返回**，我们通过 `lang` 参数传给 WB API（`?lang=en` 或 `?lang=zh`）。

---

## 💻 前端交互

1. **类别导航** — 点击切换显示该类别下的指标
2. **国家/指标多选** — `<select multiple>` 支持多选
3. **年份范围** — 起始年和结束年选择
4. **加载数据** — 点击按钮异步获取数据
5. **表格展示** — 可排序（点击表头）
6. **趋势图** — Chart.js 折线图展示趋势
7. **搜索** — 输入关键词实时搜索指标
8. **语言切换** — 右上角切换，刷新页面

---

## ⚡ 注意事项（来自 V 0.5.2 坑点）

- 模板变量来自 handler **局部作用域**，不能直接引用 App/Context 字段
- 使用 `ctx.query['id']`，**不用**路径参数 `:id`
- 静态文件目录不要有 `.bak`/`.tmp` 文件
- `map` 赋值需要 `.clone()`
- `insert into` 的 `or` 块需要返回 `int`（`or { 0 }`） 
- 使用 `vlib/json2`（`import json2`）
- 使用 `vlib/i18n` 的 `load_tr_map()` + `tr_from_map()`

---

## 你意下如何？

这个方案是否和你想的一致？如果方案没问题，我会：

1. 创建项目结构和 v.mod
2. 实现 models.v（数据模型，约 80 行）
3. 实现 wbapi.v（世界银行 API 客户端，约 180 行）
4. 实现 app.v + main.v（Web 应用 + 路由，约 150 行）
5. 创建翻译文件 en.json / zh.json
6. 创建前端模板和静态文件（HTML/CSS/JS）
7. 编译验证