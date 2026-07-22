# 🌍 World Bank Data Explorer

一个**中英文可切换**的世界银行数据展示 Web 应用，支持搜索、分类浏览、排序、筛选、趋势图展示。数据来自世界银行公开 API，后端使用 V 语言实现。

---

## 功能特性

- **📊 世界银行数据查询** — 通过官方 API 获取经济、人口、健康、教育、环境、科技、贸易等 9 大类指标
- **🌐 中英双语界面** — 一键切换语言，数据本身也通过 WB API 语言参数返回对应语言
- **📈 趋势图表** — 基于 Chart.js 的折线图和柱状图，直观展示数据变化趋势
- **🔍 全文搜索** — 按指标名称实时搜索，快速定位所需指标
- **📋 可排序表格** — 按年份或数值排序，支持升序/降序
- **📥 CSV 导出** — 一键导出数据为 CSV 格式
- **⏱️ SQLite 缓存** — 自动缓存 API 响应（5 分钟 TTL），避免重复请求
- **🎯 多国家多指标** — 支持选择多个国家和指标进行对比

## 技术栈

| 组件 | 技术 |
|------|------|
| 后端语言 | V 0.5.2 |
| Web 框架 | `net.http.Server` + `Handler` 接口 |
| 数据库 | SQLite（`db.sqlite`） |
| 模板引擎 | 服务端字符串替换（无外部依赖） |
| i18n | `vlib/i18n` 模块 |
| 前端 | 原生 HTML + CSS + JavaScript |
| 图表 | Chart.js（CDN） |
| 数据源 | [World Bank API v2](https://api.worldbank.org/v2) |

## 快速开始

### 前置条件

- V 编译器（≥ 0.5.2）：[安装指南](https://github.com/vlang/v)
- Windows / Linux / macOS

### 构建与运行

```bash
# 克隆项目
git clone <repo-url> show_worldbank
cd show_worldbank

# 编译
v -o bin/app.exe .

# 运行
bin/app.exe
```

启动后访问 **http://localhost:3003/**

### 开发模式

```bash
# 带调试信息的构建
v -g -o bin/app.exe .

# 运行并观察输出
bin/app.exe
```

## 项目结构

```
show_worldbank/
├── main.v                  # 入口：App 结构体、SQLite 初始化、HTTP 服务器
├── handlers.v              # HTTP 路由处理函数、i18n 辅助、SQLite 缓存
├── wbapi.v                 # 世界银行 API 客户端（代理、缓存、解析）
├── models.v                # 数据模型 + 预定义类别与指标 + 常量
├── v.mod                   # V 模块定义
├── translations/
│   ├── en.json             # 英文界面翻译
│   └── zh.json             # 中文界面翻译
├── templates/
│   └── index.html          # 主页面 HTML 模板
├── static/
│   ├── app.js              # 前端交互（搜索/排序/图表/CSV）
│   └── style.css           # 全局样式
├── data/
│   └── wbcache.db          # SQLite 缓存数据库（自动创建）
├── bin/
│   └── app.exe             # 编译后的可执行文件
└── docs/                   # 文档
```

## API 端点

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/` | 首页（主页面） |
| GET | `/set-lang?lang=en\|zh` | 切换语言（设置 Cookie） |
| GET | `/api/categories` | 获取所有类别及指标列表 |
| GET | `/api/countries` | 获取国家列表 |
| GET | `/api/indicators` | 按类别获取指标 |
| GET | `/api/data?indicator=X&country=Y&year_start=Z&year_end=W` | 获取指标数据 |
| GET | `/api/search?q=keyword` | 搜索指标 |
| GET | `/style.css` | CSS 样式文件 |
| GET | `/app.js` | JavaScript 脚本 |

详细 API 文档见 [docs/API.md](docs/API.md)。

## 数据类别

| 类别 ID | 中文名 | 指标数 | 示例 |
|---------|--------|--------|------|
| `economy` | 经济 | 7 | GDP、GDP 增长、通胀、失业率 |
| `population` | 人口 | 8 | 总人口、增长率、出生率、预期寿命 |
| `health` | 健康 | 5 | 婴儿死亡率、医疗支出、免疫率 |
| `education` | 教育 | 5 | 入学率、识字率、完成率 |
| `environment` | 环境 | 5 | CO₂ 排放、森林面积、电力消耗 |
| `technology` | 科技 | 5 | 互联网使用率、手机普及率、研发支出 |
| `trade` | 贸易 | 4 | 进出口额、贸易占 GDP 比重 |
| `debt` | 债务与金融 | 4 | 外债总额、政府债务、FDI |
| `poverty` | 贫困与不平等 | 5 | 贫困率、GINI 系数、收入份额 |

## 数据流

```
浏览器 ──GET /──→ Veb ──→ index.html（含类别导航及所有 UI 标签）
浏览器 ──GET /api/categories──→ JSON（预定义类别 + 指标列表）
浏览器 ──GET /api/countries──→ Veb ──→ WB API（带 SQLite 缓存）
浏览器 ──GET /api/data?indicator=X&country=Y──→ Veb ──→ WB API（带 SQLite 缓存）
浏览器 ──GET /api/search?q=X──→ Veb ──→ 本地搜索（预定义指标）
```

## 缓存策略

- 使用 SQLite 数据库存储 API 响应缓存
- 缓存键格式：`countries_{lang}`、`data_{indicator}_{country}_{year_start}_{year_end}_{lang}`
- 缓存 TTL：5 分钟（`cache_ttl_ms = 300000`）
- 缓存命中直接返回，未命中则请求 WB API 并存入缓存

## 常见问题

### 1. 服务器启动后页面无法访问？
确认防火墙允许 3003 端口，或使用 `http://127.0.0.1:3003/` 访问。

### 2. 数据加载缓慢？
首次请求会从世界银行 API 拉取数据，取决于网络状况。后续请求会自动从 SQLite 缓存读取。

### 3. 如何更换端口？
修改 `main.v` 中 `server.addr` 的值（如 `':9090'`），然后重新编译。

### 4. 编译错误？
确保使用 V 0.5.2 或更新版本。此项目不依赖 `veb` 框架，使用 `net.http.Server` 避免 comptime 兼容性问题。

## License

MIT
