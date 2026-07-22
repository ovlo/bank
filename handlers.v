module main

import net.http
import json2
import os
import time
import i18n

// ============================================================
// 辅助函数
// ============================================================

// tr — i18n 翻译
fn (app App) tr(lang string, key string) string {
	return i18n.tr_from_map(app.translations, lang, key)
}

// get_lang — 从请求 Cookie 中获取语言偏好
fn get_lang(req http.Request) string {
	cookies := http.read_cookies(req.header, 'lang')
	if cookies.len > 0 {
		lang := cookies[0].value
		if lang == 'en' || lang == 'zh' {
			return lang
		}
	}
	return 'en'
}

// parse_query — 从 URL 中提取查询参数
fn parse_query(url_str string) map[string]string {
	mut result := map[string]string{}
	qmark := url_str.index('?') or { return result }
	query_str := url_str[qmark + 1..]
	if query_str.len == 0 {
		return result
	}
	for part in query_str.split('&') {
		eq := part.index('=') or { continue }
		key := part[..eq]
		value := part[eq + 1..]
		result[key] = value
	}
	return result
}

// json_response — 创建 JSON 响应
fn json_response(data string) http.Response {
	mut h := http.new_header()
	h.add(.content_type, 'application/json')
	return http.Response{
		status_code: 200
		body: data
		header: h
	}
}

// html_response — 创建 HTML 响应
fn html_response(body string) http.Response {
	mut h := http.new_header()
	h.add(.content_type, 'text/html; charset=utf-8')
	return http.Response{
		status_code: 200
		body: body
		header: h
	}
}

// ============================================================
// SQLite 缓存
// ============================================================

// cache_get — 从 SQLite 获取缓存
fn (app App) cache_get(key string) ?string {
	rows := app.db.exec_param2('SELECT value FROM cache WHERE key = ? AND created_at > ?',
		key, (time.now().unix_milli() - cache_ttl_ms).str()) or {
		return none
	}
	if rows.len == 0 {
		return none
	}
	return rows[0].vals[0]
}

// cache_set — 写入 SQLite 缓存
fn (app App) cache_set(key string, value string) {
	app.db.exec_param_many('INSERT OR REPLACE INTO cache (key, value, created_at) VALUES (?, ?, ?)',
		[key, value, time.now().unix_milli().str()]) or {
		eprintln('cache set error: ${err}')
	}
}

// ============================================================
// 路由处理函数
// ============================================================

// handle_index — GET /
pub fn (mut app App) handle_index(req http.Request) http.Response {
	lang := get_lang(req)

	mut html := app.template_html

	// 替换模板变量
	html = html.replace('@current_lang', lang)
	html = html.replace('@page_title', app.tr(lang, 'app_title'))
	html = html.replace('@nav_home', app.tr(lang, 'nav_home'))
	html = html.replace('@nav_categories', app.tr(lang, 'nav_categories'))
	html = html.replace('@nav_search', app.tr(lang, 'nav_search'))
	html = html.replace('@search_placeholder', app.tr(lang, 'search_placeholder'))
	html = html.replace('@btn_search', app.tr(lang, 'search'))
	html = html.replace('@btn_load_data', app.tr(lang, 'load_data'))
	html = html.replace('@label_country', app.tr(lang, 'country'))
	html = html.replace('@label_indicator', app.tr(lang, 'indicator'))
	html = html.replace('@label_year_range', app.tr(lang, 'year_range'))
	html = html.replace('@label_year_start', app.tr(lang, 'year_start'))
	html = html.replace('@label_year_end', app.tr(lang, 'year_end'))
	html = html.replace('@label_sort_by', app.tr(lang, 'sort_by'))
	html = html.replace('@label_year', app.tr(lang, 'year'))
	html = html.replace('@label_value', app.tr(lang, 'value'))
	html = html.replace('@no_data', app.tr(lang, 'no_data'))
	html = html.replace('@loading', app.tr(lang, 'loading'))
	html = html.replace('@error_text', app.tr(lang, 'error'))
	html = html.replace('@table_title', app.tr(lang, 'table_title'))
	html = html.replace('@chart_title', app.tr(lang, 'chart_title'))
	html = html.replace('@select_country', app.tr(lang, 'select_country'))
	html = html.replace('@select_indicator', app.tr(lang, 'select_indicator'))
	html = html.replace('@select_category', app.tr(lang, 'select_category'))
	html = html.replace('@ascending', app.tr(lang, 'ascending'))
	html = html.replace('@descending', app.tr(lang, 'descending'))
	html = html.replace('@chart_type', app.tr(lang, 'chart_type'))
	html = html.replace('@line_chart', app.tr(lang, 'line_chart'))
	html = html.replace('@bar_chart', app.tr(lang, 'bar_chart'))
	html = html.replace('@export_csv', app.tr(lang, 'export_csv'))
	html = html.replace('@country_filter', app.tr(lang, 'country_filter'))
	html = html.replace('@custom_indicator', app.tr(lang, 'custom_indicator'))
	html = html.replace('@custom_indicator_id', app.tr(lang, 'custom_indicator_id'))
	html = html.replace('@custom_indicator_name', app.tr(lang, 'custom_indicator_name'))
	html = html.replace('@add_indicator', app.tr(lang, 'add_indicator'))
	html = html.replace('@tab_custom', app.tr(lang, 'tab_custom'))
	html = html.replace('@overview_title', app.tr(lang, 'overview_title'))
	html = html.replace('@overview_subtitle', app.tr(lang, 'overview_subtitle'))
	html = html.replace('@overview_chart_title', app.tr(lang, 'overview_chart_title'))

	lang_en_sel := if lang == 'en' { 'selected' } else { '' }
	lang_zh_sel := if lang == 'zh' { 'selected' } else { '' }
	html = html.replace('@lang_en_selected', lang_en_sel)
	html = html.replace('@lang_zh_selected', lang_zh_sel)
	html = html.replace('@categories_json', app.get_categories_json(lang))

	return html_response(html)
}

// handle_set_lang — GET /set-lang?lang=en|zh
pub fn (app App) handle_set_lang(req http.Request) http.Response {
	params := parse_query(req.url)
	lang := params['lang'] or { 'en' }
	if lang != 'en' && lang != 'zh' {
		mut h := http.new_header()
		h.add(.content_type, 'text/plain')
		return http.Response{ status_code: 400, body: 'Invalid lang', header: h }
	}
	mut h := http.new_header()
	h.add(.location, '/')
	h.add_custom('Set-Cookie', 'lang=${lang}; Path=/; Max-Age=31536000') or {}
	return http.Response{ status_code: 302, status_msg: 'Found', body: '', header: h }
}

// handle_api_categories — GET /api/categories
pub fn (app App) handle_api_categories(req http.Request) http.Response {
	lang := get_lang(req)
	return json_response(app.get_categories_json(lang))
}

// get_categories_json — 返回类别 JSON（包含指标列表）
fn (app App) get_categories_json(lang string) string {
	mut cats := []map[string]json2.Any{}
	for cat in default_categories {
		mut indicators := []json2.Any{}
		for ind in cat.indicators {
			indicators << json2.Any({
				'id':   json2.Any(ind.id)
				'name': json2.Any(ind.name)
			})
		}
		cat_name := if lang == 'zh' { cat.name_zh } else { cat.name_en }
		cats << {
			'id':         json2.Any(cat.id)
			'name':       json2.Any(cat_name)
			'indicators': json2.Any(indicators)
		}
	}
	return json2.encode[[]map[string]json2.Any](cats, json2.EncoderOptions{})
}

// handle_api_regions_overview — GET /api/regions-overview
pub fn (mut app App) handle_api_regions_overview(req http.Request) http.Response {
	lang := get_lang(req)
	overview := app.fetch_all_regions_overview(lang) or {
		return json_response('{"error":"${err}"}')
	}
	return json_response(json2.encode[[]RegionSummary](overview, json2.EncoderOptions{}))
}

// handle_api_countries — GET /api/countries
pub fn (mut app App) handle_api_countries(req http.Request) http.Response {
	lang := get_lang(req)
	countries := app.fetch_countries(lang) or {
		return json_response('{"error":"${err}"}')
	}
	return json_response(json2.encode[[]Country](countries, json2.EncoderOptions{}))
}

// handle_api_data — GET /api/data?indicator=X&country=Y&year_start=Z&year_end=W
pub fn (mut app App) handle_api_data(req http.Request) http.Response {
	params := parse_query(req.url)
	indicator := params['indicator'] or {
		return json_response('{"error":"missing indicator"}')
	}
	country := params['country'] or {
		return json_response('{"error":"missing country"}')
	}
	year_start := params['year_start'] or { '2000' }
	year_end := params['year_end'] or { '2023' }
	lang := get_lang(req)

	record := app.fetch_indicator_data(indicator, country, year_start.int(), year_end.int(), lang) or {
		return json_response('{"error":"${err}"}')
	}
	return json_response(json2.encode[DataRecord](record, json2.EncoderOptions{}))
}

// handle_api_search — GET /api/search?q=X（本地 + WB API）
pub fn (mut app App) handle_api_search(req http.Request) http.Response {
	params := parse_query(req.url)
	q := params['q'] or { return json_response('[]') }
	if q.len < 1 {
		return json_response('[]')
	}
	lang := get_lang(req)
	   results := search_indicators_wb(q, lang) or {
	       search_indicators_local(q, lang)
	   }
	return json_response(json2.encode[[]SearchResult](results, json2.EncoderOptions{}))
}

// search_indicators_local — 本地搜索（回退方案）
fn search_indicators_local(query string, lang string) []SearchResult {
	q := query.to_lower()
	mut results := []SearchResult{}
	for cat in default_categories {
		for ind in cat.indicators {
			name_lower := ind.name.to_lower()
			if name_lower.contains(q) {
				results << SearchResult{
					indicator_id: ind.id
					indicator_name: ind.name
					category: if lang == 'zh' { cat.name_zh } else { cat.name_en }
					description: ind.description
				}
			}
		}
	}
	return results
}

// serve_static — 提供静态文件
pub fn (app App) serve_static(path string) http.Response {
	file_path := path.trim_left('/')
	full_path := 'static/${file_path}'
	if !os.exists(full_path) {
		mut h := http.new_header()
		h.add(.content_type, 'text/plain')
		return http.Response{ status_code: 404, body: 'Not found', header: h }
	}
	mut content_type := 'text/plain'
	if file_path.ends_with('.css') {
		content_type = 'text/css'
	} else if file_path.ends_with('.js') {
		content_type = 'application/javascript'
	}
	data := os.read_file(full_path) or {
		mut h := http.new_header()
		h.add(.content_type, 'text/plain')
		return http.Response{ status_code: 404, body: 'Not found', header: h }
	}
	mut h := http.new_header()
	h.add(.content_type, content_type)
	return http.Response{ status_code: 200, body: data, header: h }
}
