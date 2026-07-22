module main

import net.http
import json2
// ============================================================
// wb_fetch — 通用的世界银行 API 请求函数
// ============================================================
fn wb_fetch(url string) !string {
	resp := http.get(url) or {
		return error('HTTP request failed: ${err}')
	}
	if resp.status_code != 200 {
		return error('World Bank API returned status ${resp.status_code}')
	}
	return resp.body
}

// wb_parse_envelope — 解析 WB API 的 [meta, data...] 信封格式
fn wb_parse_envelope(body string) !([]json2.Any, map[string]json2.Any) {
	arr := json2.decode[[]json2.Any](body, json2.DecoderOptions{}) or {
		return error('JSON decode failed: ${err}')
	}
	if arr.len < 2 {
		return error('Unexpected WB API response format (len=${arr.len})')
	}
	meta := arr[0].as_map()
	data_arr := arr[1].as_array()
	return data_arr, meta
}

// wb_value_or_none — 从 WB 数据条目中提取数值
fn wb_value_or_none(entry map[string]json2.Any) ?f64 {
	val := entry['value'] or { json2.Any{} }
	if val.json_str() == 'null' {
		return none
	}
	return val.f64()
}

// ============================================================
// 构建 URL
// ============================================================

fn build_wb_url(path string, params map[string]string) string {
	base := 'https://api.worldbank.org/v2'
	mut url := '${base}${path}?format=json'
	for k, v in params {
		url += '&${k}=${v}'
	}
	return url
}

// ============================================================
// fetch_region_latest_values — 批量获取区域的概览指标最新值
// ============================================================
fn (mut app App) fetch_region_latest_values(region_code string, lang string) ![]RegionSummary {
	cache_key := 'region_overview_${region_code}_${lang}'
	cached := app.cache_get(cache_key)
	if cached != none {
		return json2.decode[[]RegionSummary](cached, json2.DecoderOptions{}) or {
			return error('cache decode: ${err}')
		}
	}

	mut items := []WorldSummaryItem{}
	for oi in overview_indicators {
		// 使用 region_code 作为国家参数
		url := build_wb_url('/country/${region_code}/indicator/${oi.id}', {
			'per_page': '10'
			'date':     '2010:2025'
			'lang':     lang
		})
		body := wb_fetch(url) or { continue }
		data_arr, _ := wb_parse_envelope(body) or { continue }

		mut latest_year := -1
		mut latest_val := 0.0
		mut ind_name := oi.name

		for item in data_arr {
			m := item.as_map()
			// 从第一个条目获取指标名称
			if ind_name == oi.name {
				indicator_field := m['indicator'] or { json2.Any{} }
				if ind_name_from_map := indicator_field.as_map()['value'] {
					ind_name = ind_name_from_map.str()
				}
			}
			date_str := m['date'] or { json2.Any{} }.str()
			year := date_str.int()
			val := wb_value_or_none(m)
			if val != none && year > latest_year {
				latest_year = year
				latest_val = val
			}
		}

		if latest_year > 0 {
			items << WorldSummaryItem{
				indicator_id:   oi.id
				indicator_name: ind_name
				category:       oi.category
				value:          latest_val
				year:           latest_year
			}
		}
	}

	mut summaries := []RegionSummary{}
	// 查找 region 的名称
	mut region_name := region_code
	for r in important_regions {
		if r.code == region_code {
			region_name = if lang == 'zh' { r.name_zh } else { r.name_en }
			break
		}
	}
	summaries << RegionSummary{
		region_code: region_code
		region_name: region_name
		items: items
	}

	app.cache_set(cache_key, json2.encode[[]RegionSummary](summaries, json2.EncoderOptions{}))
	return summaries
}

// ============================================================
// fetch_all_regions_overview — 批量获取所有重要区域的概览
// ============================================================
fn (mut app App) fetch_all_regions_overview(lang string) ![]RegionSummary {
	cache_key := 'all_regions_overview_${lang}'
	cached := app.cache_get(cache_key)
	if cached != none {
		return json2.decode[[]RegionSummary](cached, json2.DecoderOptions{}) or {
			return error('cache decode: ${err}')
		}
	}

	mut all := []RegionSummary{}
	for r in important_regions {
		region_data := app.fetch_region_latest_values(r.code, lang) or { continue }
		if region_data.len > 0 {
			all << region_data[0]
		}
	}

	app.cache_set(cache_key, json2.encode[[]RegionSummary](all, json2.EncoderOptions{}))
	return all
}

// ============================================================
// 国家相关
// ============================================================

// fetch_countries — 获取所有国家列表（包含 WLD World 在首位）
fn (mut app App) fetch_countries(lang string) ![]Country {
	cache_key := 'countries_${lang}'
	cached := app.cache_get(cache_key)
	if cached != none {
		mut countries := json2.decode[[]Country](cached, json2.DecoderOptions{}) or {
			return error('cache decode: ${err}')
		}
		return app.ensure_world_first(countries, lang)
	}

	url := build_wb_url('/country', {
		'per_page': '300'
		'lang':     lang
	})
	body := wb_fetch(url)!
	data_arr, _ := wb_parse_envelope(body)!

	mut countries := []Country{}
	for item in data_arr {
		m := item.as_map()
		iso2 := m['iso2Code'] or { json2.Any{} }.str()
		iso3 := m['id'] or { json2.Any{} }.str()
		if iso3.len != 3 { continue }
		country := Country{
			iso2: iso2
			iso3: iso3
			name: m['name'] or { json2.Any{} }.str()
		}
		countries << country
	}

	app.cache_set(cache_key, json2.encode[[]Country](countries, json2.EncoderOptions{}))
	return app.ensure_world_first(countries, lang)
}

// ensure_world_first — 确保 WLD (World) 排在首位
fn (app App) ensure_world_first(countries []Country, lang string) []Country {
	mut result := []Country{}
	world_name := if lang == 'zh' { '🌍 世界 (World)' } else { '🌍 World' }
	result << Country{iso2: '1W', iso3: 'WLD', name: world_name}
	for c in countries {
		if c.iso3 != 'WLD' {
			result << c
		}
	}
	return result
}

// ============================================================
// fetch_indicator_data — 获取单个指标的完整时序数据
// ============================================================
fn (mut app App) fetch_indicator_data(indicator_id string, country_iso3 string, year_start int, year_end int, lang string) !DataRecord {
	actual_country := if country_iso3 == 'WLD' { '1W' } else { country_iso3 }

	cache_key := 'data_${indicator_id}_${country_iso3}_${year_start}_${year_end}_${lang}'
	cached := app.cache_get(cache_key)
	if cached != none {
		return json2.decode[DataRecord](cached, json2.DecoderOptions{}) or {
			return error('cache decode: ${err}')
		}
	}

	indicator_name := get_indicator_name(indicator_id)
	date_range := '${year_start}:${year_end}'

	url := build_wb_url('/country/${actual_country}/indicator/${indicator_id}', {
		'per_page': '200'
		'date':     date_range
		'lang':     lang
	})

	body := wb_fetch(url)!
	data_arr, _ := wb_parse_envelope(body)!

	mut points := []DataPoint{}
	for item in data_arr {
		m := item.as_map()
		date_str := m['date'] or { json2.Any{} }.str()
		year := date_str.int()
		val := wb_value_or_none(m)
		if val != none {
			points << DataPoint{
				year: year
				value: val
			}
		}
	}

	// 按年份排序
	mut i := 0
	for i < points.len {
		mut j := i + 1
		for j < points.len {
			if points[j].year < points[i].year {
				points[i], points[j] = points[j], points[i]
			}
			j++
		}
		i++
	}

	record := DataRecord{
		indicator_id: indicator_id
		indicator_name: indicator_name
		country_iso3: country_iso3
		country_name: if country_iso3 == 'WLD' { 'World' } else { '' }
		points: points
	}

	app.cache_set(cache_key, json2.encode[DataRecord](record, json2.EncoderOptions{}))
	return record
}

// ============================================================
// 搜索
// ============================================================

// search_indicators_wb — 搜索指标（本地搜索 + WB API 搜索）
fn search_indicators_wb(query string, lang string) ![]SearchResult {
	q := query.to_lower()

	// 1. 本地搜索
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

	// 2. WB API 搜索（补充）
	search_url := build_wb_url('/indicator', {
		'search':   query
		'per_page': '10'
		'lang':     lang
	})
	body := wb_fetch(search_url) or {
		return results
	}
	data_arr, _ := wb_parse_envelope(body) or {
		return results
	}

	mut existing_ids := map[string]bool{}
	for r in results {
		existing_ids[r.indicator_id] = true
	}

	for item in data_arr {
		m := item.as_map()
		ind_id := m['id'] or { json2.Any{} }.str()
		if existing_ids[ind_id] { continue }

		indicator_val := m['name'] or { json2.Any{} }.str()
		if indicator_val == '' { continue }

		results << SearchResult{
			indicator_id: ind_id
			indicator_name: indicator_val
			category: if lang == 'zh' { '外部搜索' } else { 'External' }
			description: ''
		}
		existing_ids[ind_id] = true
	}

	return results
}

// get_indicator_name — 根据 ID 获取指标名称
fn get_indicator_name(id string) string {
	for cat in default_categories {
		for ind in cat.indicators {
			if ind.id == id {
				return ind.name
			}
		}
	}
	return id
}
