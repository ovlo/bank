# show_worldbank — AGENTS.md

## Build & Run

```bash
v -o bin/app.exe .   # build
bin/app.exe           # run on :3003
```

No test/lint setup. No dependencies beyond V compiler (≥0.5.2).

## Architecture

- **V language** app using `net.http.Server` + `http.Handler` interface — NOT the `veb` framework.
- Categories & indicators are **hardcoded** in `models.v` as the `default_categories` const (~50 indicators across 9 categories). NEVER fetched from WB API.
- Indicators are server-rendered into `templates/index.html` via `@categories_json` → `window.CATEGORIES_DATA` in JS. No AJAX call for categories.
- SQLite cache at `data/wbcache.db`. Cache TTL: **7 days** (`604800000 ms`). Keys: `countries_{lang}`, `data_{indicator}_{country}_{start}_{end}_{lang}`, `region_overview_{region}_{lang}`, `all_regions_overview_{lang}`.
- i18n: `vlib/i18n` loading `.tr` files from `translations/` dir. Uses `i18n.load_tr_map_from_dir` + `i18n.tr_from_map`.
- Templates use `@variable` placeholders replaced in `handle_index()` in `handlers.v`.
- JSON library: `json2` (not `json`).
- `fetch_region_latest_values` and `fetch_all_regions_overview` make batch WB API calls at first request — can be slow on cold start/cache miss.

## Key Gotchas

- **First category is auto-selected on page load** in `app.js:initCategories()`. If an agent changes this behavior, call `selectCategory(cats[0].id)` after the loop.
- `cache_ttl_ms` in `models.v` is 604800000 (7 days). Docs say 5 min — docs are stale.
- Translation files use `.tr` extension (key-value-pair format), NOT `.json` despite the docs saying JSON.
- WB API uses envelope format `[meta, data...]` — parsed by `wb_parse_envelope()`.
- `fetch_countries` injects `WLD` (World) as the first country. `fetch_indicator_data` maps `WLD` → `1W` for WB API.

## Project Layout

| Path | Purpose |
|------|---------|
| `main.v` | Entrypoint, App struct, SQLite init, HTTP server |
| `handlers.v` | Route handlers, SQLite cache helpers, template rendering |
| `wbapi.v` | World Bank API client (fetch, parse, cache) |
| `models.v` | Data structs, constants (categories, indicators, regions) |
| `templates/index.html` | Single-page template with `@variable` placeholders |
| `static/app.js` | Frontend: search, sort, charts (Chart.js), CSV export |
| `static/style.css` | Responsive styles |
| `translations/*.tr` | i18n key-value files |
