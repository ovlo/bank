module main

import os
import i18n
import net.http
import db.sqlite
import time

// App — 应用主结构体（实现 http.Handler 接口）
pub struct App {
pub:
	db            sqlite.DB
	translations  map[string]map[string]string
	template_html string // 预加载的模板内容
	started_at    i64
}

// handle — 实现 http.Handler 接口，分发请求
pub fn (mut app App) handle(req http.Request) http.Response {
	url := req.url

	// 路由分发
	if url == '/' || url == '' {
		return app.handle_index(req)
	}
	if url.starts_with('/set-lang') {
		return app.handle_set_lang(req)
	}
	if url.starts_with('/api/countries') {
		return app.handle_api_countries(req)
	}
	if url.starts_with('/api/categories') {
		return app.handle_api_categories(req)
	}
	if url.starts_with('/api/data') {
		return app.handle_api_data(req)
	}
	if url.starts_with('/api/search') {
		return app.handle_api_search(req)
	}
	if url.starts_with('/api/regions-overview') {
		return app.handle_api_regions_overview(req)
	}
	if url == '/style.css' || url == '/app.js' {
		return app.serve_static(url)
	}
	// 404
	mut h := http.new_header()
	h.add(.content_type, 'text/plain')
	return http.Response{ status_code: 404, body: '404 Not Found', header: h }
}

fn main() {
	// 创建 data 目录
	os.mkdir_all('data') or {}

	// 打开 SQLite 数据库
	db := sqlite.connect('data/wbcache.db') or {
		panic('Failed to open SQLite: ${err}')
	}

	// 建表
	db.exec('CREATE TABLE IF NOT EXISTS cache (key TEXT PRIMARY KEY, value TEXT, created_at INTEGER)') or {
		eprintln('Create table: ${err}')
	}

	// 加载翻译
	translations := i18n.load_tr_map_from_dir('translations')

	// 读取模板 HTML
	tpl_content := os.read_file('templates/index.html') or {
		panic('Cannot read templates/index.html: ${err}')
	}

	mut app := &App{
		db: db
		translations: translations
		template_html: tpl_content
		started_at: time.now().unix_milli()
	}

	mut server := http.Server{
		addr: ':3003'
		handler: app
		show_startup_message: true
	}

	println('[wbde] World Bank Data Explorer starting on http://localhost:3003/')
	server.listen_and_serve()
}
