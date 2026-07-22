# API 文档

World Bank Data Explorer 后端 API 文档。

---

## 基础 URL

```
http://localhost:3003
```

## 通用说明

- JSON 响应的 `Content-Type` 均为 `application/json`
- HTML 响应的 `Content-Type` 为 `text/html; charset=utf-8`
- 语言偏好通过 Cookie `lang` 传递（值为 `en` 或 `zh`）
- 所有 API 端点均为 GET 请求

---

## 1. 首页

```
GET /
```

返回完整的 HTML 页面，包含所有 UI 元素、类别导航、搜索框、图表容器等。

**语言**: 通过 Cookie `lang` 确定（默认 `en`）

---

## 2. 切换语言

```
GET /set-lang?lang=en|zh
```

**参数**:

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `lang` | string | 是 | `en` 或 `zh` |

**响应**: 302 重定向到 `/`，并设置 `Set-Cookie` 头

**示例**:
```bash
curl -v http://localhost:3003/set-lang?lang=zh
```

---

## 3. 获取类别

```
GET /api/categories
```

返回所有预定义数据类别及其包含的指标列表。

**响应格式**:
```json
[
  {
    "id": "economy",
    "name": "Economy",
    "indicators": [
      { "id": "NY.GDP.MKTP.CD", "name": "GDP (current US$)" },
      { "id": "NY.GDP.MKTP.KD.ZG", "name": "GDP growth (annual %)" }
    ]
  }
]
```

**语言**: 通过 Cookie `lang` 确定指标名称语言

---

## 4. 获取国家列表

```
GET /api/countries
```

返回世界银行所有国家的列表（ISO3 编码、ISO2 编码、名称）。

**响应格式**:
```json
[
  {
    "iso2": "CN",
    "iso3": "CHN",
    "name": "China"
  },
  {
    "iso2": "US",
    "iso3": "USA",
    "name": "United States"
  }
]
```

**缓存**: SQLite 缓存 5 分钟

**语言**: 通过 Cookie `lang` 确定国家名称语言

---

## 5. 获取指标数据

```
GET /api/data?indicator=NY.GDP.MKTP.CD&country=CHN&year_start=2000&year_end=2023
```

**参数**:

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `indicator` | string | 是 | — | 世界银行指标 ID（如 `NY.GDP.MKTP.CD`） |
| `country` | string | 是 | — | 国家 ISO3 编码（如 `CHN`、`USA`） |
| `year_start` | int | 否 | `2000` | 起始年份 |
| `year_end` | int | 否 | `2023` | 结束年份 |

**响应格式**:
```json
{
  "indicator_id": "NY.GDP.MKTP.CD",
  "indicator_name": "GDP (current US$)",
  "country_iso3": "CHN",
  "points": [
    { "year": 2000, "value": 1211346869605.39 },
    { "year": 2001, "value": 1339400000000.0 }
  ]
}
```

**缓存**: SQLite 缓存 5 分钟（键包含 indicator + country + 年份范围 + lang）

**语言**: 通过 Cookie `lang` 确定

**示例**:
```bash
# 获取中国的 GDP 数据（2000-2023）
curl "http://localhost:8080/api/data?indicator=NY.GDP.MKTP.CD&country=CHN&year_start=2000&year_end=2023"
```

---

## 6. 搜索指标

```
GET /api/search?q=gdp
```

**参数**:

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `q` | string | 是 | — | 搜索关键词（大小写不敏感） |

**响应格式**:
```json
[
  {
    "indicator_id": "NY.GDP.MKTP.CD",
    "indicator_name": "GDP (current US$)",
    "category": "Economy",
    "description": "GDP at market prices in current US dollars"
  }
]
```

**说明**: 本地搜索（在预定义的指标列表中按名称匹配），不请求世界银行 API

**示例**:
```bash
curl "http://localhost:3003/api/search?q=inflation"
```

---

## 7. 静态文件

```
GET /style.css
GET /app.js
```

提供 CSS 样式表和 JavaScript 脚本文件。

**Content-Type**:
- `.css` → `text/css`
- `.js` → `application/javascript`

---

## 错误处理

所有 API 端点均返回 JSON 格式的错误信息：

```json
{
  "error": "错误描述"
}
```

常见 HTTP 状态码：

| 状态码 | 说明 |
|--------|------|
| 200 | 成功 |
| 302 | 重定向（切语言时使用） |
| 400 | 请求参数错误 |
| 404 | 资源不存在 |
| 500 | 服务器内部错误（WB API 调用失败等） |
