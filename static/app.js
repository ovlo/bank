/**
 * World Bank Data Explorer — 前端交互脚本
 * 功能：类别导航、搜索、数据加载、排序、图表展示、自定义指标、国家过滤、概览看板
 */

// ============================================================
// 全局状态
// ============================================================
let myChart = null;
let overviewChart = null;
let currentData = [];
let currentIndicatorId = '';
let currentCountryCode = '';
let currentChartType = 'line';
let overviewData = [];        // 所有区域的概览数据
let selectedOverviewRegion = null; // 当前选中的区域代码
const API_BASE = '/api';

// ============================================================
// 初始化
// ============================================================
document.addEventListener('DOMContentLoaded', function () {
	initCategories();
	initCountries();
	initCustomIndicators();
	initOverview();
});

// ============================================================
// 🌍 世界概览看板
// ============================================================
function initOverview() {
	fetch(API_BASE + '/regions-overview')
		.then(function (r) { return r.json(); })
		.then(function (regions) {
			overviewData = regions;
			renderRegionTabs(regions);
			if (regions.length > 0) {
				selectOverviewRegion(regions[0].region_code);
			}
		})
		.catch(function (err) {
			console.error('Failed to load overview:', err);
			document.getElementById('overview-cards').innerHTML =
				'<span style="color:#c00;">Failed to load overview data</span>';
		});
}

function renderRegionTabs(regions) {
	const container = document.getElementById('region-tabs');
	container.innerHTML = '';
	regions.forEach(function (r) {
		const btn = document.createElement('button');
		btn.className = 'region-tab';
		btn.textContent = r.region_name;
		btn.dataset.code = r.region_code;
		btn.onclick = function () { selectOverviewRegion(r.region_code); };
		container.appendChild(btn);
	});
}

function selectOverviewRegion(code) {
	selectedOverviewRegion = code;
	// 高亮标签
	document.querySelectorAll('.region-tab').forEach(function (btn) {
		btn.classList.toggle('active', btn.dataset.code === code);
	});

	const region = overviewData.find(function (r) { return r.region_code === code; });
	if (!region || !region.items) {
		document.getElementById('overview-cards').innerHTML =
			'<span style="color:var(--text-light);">No data available</span>';
		return;
	}

	renderOverviewCards(region.items);

	// 如果有多个区域，也渲染对比图
	if (overviewData.length > 1) {
		renderOverviewChart();
	}
}

function renderOverviewCards(items) {
	const container = document.getElementById('overview-cards');
	container.innerHTML = '';
	if (!items || items.length === 0) {
		container.innerHTML = '<span style="color:var(--text-light);">No data available for this region</span>';
		return;
	}

	items.forEach(function (item) {
		const card = document.createElement('div');
		card.className = 'overview-card';

		const valueSpan = document.createElement('div');
		valueSpan.className = 'oc-value';
		// 格式化数值
		let formatted;
		if (item.value >= 1e12) {
			formatted = (item.value / 1e12).toFixed(2) + 'T';
		} else if (item.value >= 1e9) {
			formatted = (item.value / 1e9).toFixed(2) + 'B';
		} else if (item.value >= 1e6) {
			formatted = (item.value / 1e6).toFixed(2) + 'M';
		} else if (item.value >= 1e3) {
			formatted = (item.value / 1e3).toFixed(2) + 'K';
		} else if (item.value < 1) {
			formatted = item.value.toFixed(2);
		} else {
			formatted = item.value.toLocaleString(undefined, { maximumFractionDigits: 2 });
		}
		valueSpan.textContent = formatted;

		const nameSpan = document.createElement('div');
		nameSpan.className = 'oc-name';
		nameSpan.textContent = item.indicator_name || item.indicator_id;

		const yearSpan = document.createElement('div');
		yearSpan.className = 'oc-year';
		yearSpan.textContent = 'Year: ' + (item.year || 'N/A');

		const catSpan = document.createElement('div');
		catSpan.className = 'oc-category';
		catSpan.textContent = item.category;

		card.appendChild(valueSpan);
		card.appendChild(nameSpan);
		card.appendChild(yearSpan);
		card.appendChild(catSpan);

		// 点击卡片跳转到详细查询（填入对应指标到下拉框）
		card.onclick = function () {
			const indId = item.indicator_id;
			// 尝试在分类中找到它并展开
			const cats = window.CATEGORIES_DATA || [];
			for (let i = 0; i < cats.length; i++) {
				const found = cats[i].indicators.find(function (ind) { return ind.id === indId; });
				if (found) {
					selectCategory(cats[i].id);
					const sel = document.getElementById('indicator-select');
					sel.value = indId;
					// 预选 WLD
					const countrySel = document.getElementById('country-select');
					for (let j = 0; j < countrySel.options.length; j++) {
						countrySel.options[j].selected = (countrySel.options[j].value === 'WLD');
					}
					loadData();
					document.querySelector('.controls-panel').scrollIntoView({ behavior: 'smooth' });
					return;
				}
			}
		};
		card.style.cursor = 'pointer';

		container.appendChild(card);
	});
}

function renderOverviewChart() {
	const container = document.getElementById('overview-chart-container');
	container.style.display = 'block';

	// 从所有区域收集数据，按指标分组
	const allIndicators = {};
	overviewData.forEach(function (region) {
		if (!region.items) return;
		region.items.forEach(function (item) {
			if (!allIndicators[item.indicator_id]) {
				allIndicators[item.indicator_id] = {
					name: item.indicator_name,
					category: item.category,
					values: {}
				};
			}
			allIndicators[item.indicator_id].values[region.region_code] = item.value;
		});
	});

	// 选前 5 个最有代表性的指标
	const indicatorIds = Object.keys(allIndicators).slice(0, 5);
	const regions = overviewData.map(function (r) { return r.region_code; });

	const datasets = regions.map(function (code, idx) {
		const region = overviewData.find(function (r) { return r.region_code === code; });
		const data = indicatorIds.map(function (indId) {
			const ind = allIndicators[indId];
			return ind && ind.values[code] != null ? ind.values[code] : null;
		});
		const palette = [
			'#1a73e8', '#e84343', '#34a853', '#f9ab00',
			'#9c27b0', '#00acc1', '#ff6d00', '#43a047',
			'#e91e63', '#7cb342'
		];
		return {
			label: region ? region.region_name : code,
			data: data,
			backgroundColor: palette[idx % palette.length] + '88',
			borderColor: palette[idx % palette.length],
			borderWidth: 1
		};
	});

	const labels = indicatorIds.map(function (id) {
		return allIndicators[id].name.length > 20
			? allIndicators[id].name.substring(0, 20) + '...'
			: allIndicators[id].name;
	});

	const ctx = document.getElementById('overview-chart').getContext('2d');
	if (overviewChart) { overviewChart.destroy(); }

	overviewChart = new Chart(ctx, {
		type: 'bar',
		data: {
			labels: labels,
			datasets: datasets
		},
		options: {
			responsive: true,
			maintainAspectRatio: false,
			plugins: {
				legend: { position: 'top' },
				tooltip: {
					callbacks: {
						label: function (ctx) {
							return ctx.dataset.label + ': ' + (ctx.parsed.y != null ? ctx.parsed.y.toFixed(2) : 'N/A');
						}
					}
				}
			},
			scales: {
				x: {
					ticks: { maxRotation: 30 }
				},
				y: {
					beginAtZero: false
				}
			}
		}
	});
}

// ============================================================
// 类别导航
// ============================================================
function initCategories() {
	const list = document.getElementById('category-list');
	const cats = window.CATEGORIES_DATA || [];

	cats.forEach(function (cat) {
		const li = document.createElement('li');
		li.textContent = cat.name + ' (' + cat.indicators.length + ')';
		li.onclick = function () {
			selectCategory(cat.id);
			switchSidebarTab('preset');
		};
		li.dataset.catId = cat.id;
		list.appendChild(li);
	});

	if (cats.length > 0) {
		selectCategory(cats[0].id);
	}
}

function selectCategory(catId) {
	const items = document.querySelectorAll('.category-list li');
	items.forEach(function (li) {
		li.classList.toggle('active', li.dataset.catId === catId);
	});
	renderIndicatorSelect(catId);
	document.getElementById('welcome-message').style.display = 'none';
}

function renderIndicatorSelect(catId) {
	const cats = window.CATEGORIES_DATA || [];
	const cat = cats.find(function (c) { return c.id === catId; });
	if (!cat) return;

	const sel = document.getElementById('indicator-select');
	sel.innerHTML = '';
	cat.indicators.forEach(function (ind) {
		const opt = document.createElement('option');
		opt.value = ind.id;
		opt.textContent = ind.name;
		sel.appendChild(opt);
	});
	const customInds = getCustomIndicators();
	customInds.forEach(function (ind) {
		const opt = document.createElement('option');
		opt.value = ind.id;
		opt.textContent = '[Custom] ' + (ind.name || ind.id);
		sel.appendChild(opt);
	});
	if (cat.indicators.length > 0) {
		sel.value = cat.indicators[0].id;
	}
}

// ============================================================
// 国家加载 + 过滤
// ============================================================
let allCountries = [];

function initCountries() {
	const sel = document.getElementById('country-select');

	fetch(API_BASE + '/countries')
		.then(function (r) { return r.json(); })
		.then(function (countries) {
			allCountries = countries.filter(function (c) {
				return c.iso3 && c.iso3.length === 3 && c.name;
			});
			populateCountryOptions(allCountries);
			// 预选 WLD（世界）和其他常用国家
			const preselect = ['WLD', 'CHN', 'USA', 'JPN', 'DEU', 'IND', 'GBR', 'FRA', 'BRA', 'RUS', 'ZAF'];
			const options = sel.options;
			for (let i = 0; i < options.length; i++) {
				if (preselect.indexOf(options[i].value) >= 0) {
					options[i].selected = true;
				}
			}
		})
		.catch(function (err) {
			console.error('Failed to load countries:', err);
		});
}

function populateCountryOptions(countries) {
	const sel = document.getElementById('country-select');
	sel.innerHTML = '';
	countries.forEach(function (c) {
		const opt = document.createElement('option');
		opt.value = c.iso3;
		opt.textContent = c.name;
		sel.appendChild(opt);
	});
}

function filterCountries(query) {
	const q = query.toLowerCase().trim();
	if (!q) {
		populateCountryOptions(allCountries);
		return;
	}
	const filtered = allCountries.filter(function (c) {
		return c.name.toLowerCase().indexOf(q) >= 0
			|| c.iso3.toLowerCase().indexOf(q) >= 0
			|| c.iso2.toLowerCase().indexOf(q) >= 0;
	});
	populateCountryOptions(filtered);
}

// ============================================================
// 自定义指标
// ============================================================
const CUSTOM_IND_KEY = 'wb_custom_indicators';

function getCustomIndicators() {
	try { return JSON.parse(localStorage.getItem(CUSTOM_IND_KEY)) || []; }
	catch (e) { return []; }
}

function saveCustomIndicators(list) {
	localStorage.setItem(CUSTOM_IND_KEY, JSON.stringify(list));
}

function initCustomIndicators() { renderCustomList(); }

function renderCustomList() {
	const list = document.getElementById('custom-list');
	const inds = getCustomIndicators();
	list.innerHTML = '';
	if (inds.length === 0) {
		list.innerHTML = '<li style="color:var(--text-light);font-size:0.82rem;padding:8px 12px;">No custom indicators yet.</li>';
		return;
	}
	inds.forEach(function (ind, idx) {
		const li = document.createElement('li');
		li.className = 'custom-item';
		const nameSpan = document.createElement('span');
		nameSpan.className = 'ci-name';
		nameSpan.textContent = ind.name || ind.id;
		const idSpan = document.createElement('span');
		idSpan.className = 'ci-id';
		idSpan.textContent = ind.id;
		const delBtn = document.createElement('span');
		delBtn.className = 'ci-remove';
		delBtn.textContent = '×';
		delBtn.title = 'Remove';
		delBtn.onclick = function (e) { e.stopPropagation(); removeCustomIndicator(idx); };
		li.onclick = function () { selectCustomIndicator(ind.id, ind.name || ind.id); };
		li.appendChild(nameSpan);
		li.appendChild(idSpan);
		li.appendChild(delBtn);
		list.appendChild(li);
	});
}

function addCustomIndicator() {
	const idInput = document.getElementById('custom-ind-id');
	const nameInput = document.getElementById('custom-ind-name');
	const id = idInput.value.trim();
	if (!id) return;
	const name = nameInput.value.trim() || id;
	const inds = getCustomIndicators();
	if (inds.some(function (i) { return i.id === id; })) {
		showError('Indicator ID "' + id + '" already exists.');
		return;
	}
	inds.push({ id: id, name: name });
	saveCustomIndicators(inds);
	renderCustomList();
	idInput.value = '';
	nameInput.value = '';
	hideError();
}

function removeCustomIndicator(idx) {
	const inds = getCustomIndicators();
	inds.splice(idx, 1);
	saveCustomIndicators(inds);
	renderCustomList();
}

function selectCustomIndicator(id, name) {
	const sel = document.getElementById('indicator-select');
	sel.innerHTML = '';
	const opt = document.createElement('option');
	opt.value = id;
	opt.textContent = '[Custom] ' + name;
	sel.appendChild(opt);
	sel.value = id;
	document.getElementById('welcome-message').style.display = 'none';
}

// ============================================================
// 侧边栏标签切换
// ============================================================
function switchSidebarTab(tab) {
	document.querySelectorAll('.sidebar-tab').forEach(function (btn) {
		btn.classList.toggle('active', btn.dataset.tab === tab);
	});
	document.getElementById('sidebar-preset').style.display = (tab === 'preset') ? 'block' : 'none';
	document.getElementById('sidebar-custom').style.display = (tab === 'custom') ? 'block' : 'none';
}

// ============================================================
// 搜索（本地 + WB API）
// ============================================================
let searchTimer = null;

function onSearchInput(query) {
	clearTimeout(searchTimer);
	const resultsDiv = document.getElementById('search-results');
	if (query.length < 2) {
		resultsDiv.style.display = 'none';
		return;
	}
	searchTimer = setTimeout(function () { doSearch(); }, 300);
}

function doSearch() {
	const query = document.getElementById('search-input').value.trim();
	const resultsDiv = document.getElementById('search-results');
	if (query.length < 2) {
		resultsDiv.style.display = 'none';
		return;
	}

	fetch(API_BASE + '/search?q=' + encodeURIComponent(query))
		.then(function (r) { return r.json(); })
		.then(function (results) {
			resultsDiv.innerHTML = '';
			if (results.length === 0) {
				resultsDiv.innerHTML = '<div class="search-result-item" style="color:#999;">No results</div>';
				resultsDiv.style.display = 'block';
				return;
			}
			results.forEach(function (r) {
				const div = document.createElement('div');
				div.className = 'search-result-item';
				div.innerHTML = '<strong>' + r.indicator_name + '</strong><br><span class="sr-category">' + r.category + '</span>';
				div.onclick = function () {
					selectIndicatorFromSearch(r.indicator_id);
					resultsDiv.style.display = 'none';
					document.getElementById('search-input').value = '';
				};
				resultsDiv.appendChild(div);
			});
			resultsDiv.style.display = 'block';
		})
		.catch(function () {
			resultsDiv.style.display = 'none';
		});
}

function selectIndicatorFromSearch(indicatorId) {
	const cats = window.CATEGORIES_DATA || [];
	for (let i = 0; i < cats.length; i++) {
		const cat = cats[i];
		const found = cat.indicators.find(function (ind) { return ind.id === indicatorId; });
		if (found) {
			selectCategory(cat.id);
			const sel = document.getElementById('indicator-select');
			sel.value = indicatorId;
			loadData();
			return;
		}
	}
	const customInds = getCustomIndicators();
	for (let i = 0; i < customInds.length; i++) {
		if (customInds[i].id === indicatorId) {
			selectCustomIndicator(indicatorId, customInds[i].name);
			loadData();
			return;
		}
	}
}

// ============================================================
// 数据加载
// ============================================================
function loadData() {
	const sel = document.getElementById('country-select');
	const selectedCountries = [];
	for (let i = 0; i < sel.options.length; i++) {
		if (sel.options[i].selected && sel.options[i].value) {
			selectedCountries.push(sel.options[i].value);
		}
	}

	const indicator = document.getElementById('indicator-select').value;
	const yearStart = document.getElementById('year-start').value;
	const yearEnd = document.getElementById('year-end').value;

	if (!indicator) { showError('Please select an indicator'); return; }
	if (selectedCountries.length === 0) { showError('Please select at least one country'); return; }

	showLoading(true);
	hideError();
	document.getElementById('welcome-message').style.display = 'none';

	currentIndicatorId = indicator;
	currentData = [];

	const promises = selectedCountries.map(function (countryCode) {
		const url = API_BASE + '/data?indicator=' + encodeURIComponent(indicator)
			+ '&country=' + encodeURIComponent(countryCode)
			+ '&year_start=' + yearStart + '&year_end=' + yearEnd;
		return fetch(url).then(function (r) { return r.json(); });
	});

	Promise.all(promises)
		.then(function (results) {
			showLoading(false);
			const allPoints = [];
			results.forEach(function (record) {
				if (record.error) { console.warn('Error:', record.error); return; }
				if (record.points) {
					record.points.forEach(function (p) {
						allPoints.push({
							year: p.year,
							value: p.value,
							country: record.country_name || record.country_iso3,
							country_iso3: record.country_iso3
						});
					});
				}
			});
			if (allPoints.length === 0) {
				showError('No data available');
				document.getElementById('data-display').style.display = 'none';
				return;
			}
			currentData = allPoints;
			renderChart(allPoints);
			renderTable(allPoints);
			document.getElementById('data-display').style.display = 'block';
		})
		.catch(function (err) {
			showLoading(false);
			showError('Failed: ' + err.message);
		});
}

// ============================================================
// 图表
// ============================================================
function renderChart(data) {
	const ctx = document.getElementById('data-chart').getContext('2d');
	const countries = [...new Set(data.map(function (d) { return d.country; }))];
	const years = [...new Set(data.map(function (d) { return d.year; }))];
	years.sort(function (a, b) { return a - b; });

	const countryColorMap = {};
	const palette = [
		'#1a73e8', '#e84343', '#34a853', '#f9ab00',
		'#9c27b0', '#00acc1', '#ff6d00', '#43a047',
		'#e91e63', '#7cb342', '#5c6bc0', '#26a69a'
	];
	let colorIdx = 0;
	countries.forEach(function (c) {
		if (!countryColorMap[c]) {
			countryColorMap[c] = palette[colorIdx % palette.length];
			colorIdx++;
		}
	});

	const datasets = countries.map(function (country) {
		const countryData = data.filter(function (d) { return d.country === country; });
		const values = years.map(function (y) {
			const found = countryData.find(function (d) { return d.year === y; });
			return found ? found.value : null;
		});
		return {
			label: country,
			data: values,
			borderColor: countryColorMap[country],
			backgroundColor: countryColorMap[country] + '33',
			borderWidth: 2,
			pointRadius: 3,
			spanGaps: true,
			tension: 0.3
		};
	});

	if (myChart) { myChart.destroy(); }

	myChart = new Chart(ctx, {
		type: currentChartType,
		data: { labels: years, datasets: datasets },
		options: {
			responsive: true,
			maintainAspectRatio: false,
			interaction: { mode: 'index', intersect: false },
			plugins: {
				legend: { position: 'top' },
				tooltip: {
					callbacks: {
						label: function (ctx) {
							return ctx.dataset.label + ': ' + (ctx.parsed.y != null ? ctx.parsed.y.toFixed(2) : 'N/A');
						}
					}
				}
			},
			scales: {
				x: { title: { display: true, text: 'Year' } },
				y: { title: { display: true, text: 'Value' }, beginAtZero: false }
			}
		}
	});
}

function toggleChartType() {
	currentChartType = (currentChartType === 'line') ? 'bar' : 'line';
	document.getElementById('chart-type-btn').textContent =
		(currentChartType === 'line') ? 'Bar Chart' : 'Line Chart';
	if (currentData.length > 0) { renderChart(currentData); }
}

// ============================================================
// 表格
// ============================================================
function renderTable(data) {
	const tbody = document.getElementById('table-body');
	tbody.innerHTML = '';
	const sortVal = document.getElementById('sort-select').value;
	data.sort(function (a, b) {
		if (sortVal === 'year-asc') return a.year - b.year;
		if (sortVal === 'year-desc') return b.year - a.year;
		if (sortVal === 'value-asc') return a.value - b.value;
		return b.value - a.value;
	});
	data.forEach(function (d) {
		const tr = document.createElement('tr');
		const td1 = document.createElement('td'); td1.textContent = d.year;
		const td2 = document.createElement('td'); td2.textContent = d.value.toFixed(4);
		tr.appendChild(td1); tr.appendChild(td2);
		tbody.appendChild(tr);
	});
}

function sortTable() { if (currentData.length > 0) renderTable(currentData); }

// ============================================================
// CSV 导出
// ============================================================
function exportCsv() {
	if (currentData.length === 0) return;
	const indicator = document.getElementById('indicator-select');
	const indicatorName = indicator.options[indicator.selectedIndex]
		? indicator.options[indicator.selectedIndex].textContent : 'Data';
	let csv = 'Year,Country,Value\n';
	currentData.forEach(function (d) {
		csv += d.year + ',"' + d.country + '",' + d.value.toFixed(4) + '\n';
	});
	const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
	const link = document.createElement('a');
	link.href = URL.createObjectURL(blob);
	link.download = indicatorName.replace(/[^a-zA-Z0-9]/g, '_') + '.csv';
	link.click();
	URL.revokeObjectURL(link.href);
}

// ============================================================
// 语言切换
// ============================================================
function switchLang(lang) { window.location.href = '/set-lang?lang=' + lang; }

// ============================================================
// 导航
// ============================================================
function scrollToCategories() { document.querySelector('.sidebar').scrollIntoView({ behavior: 'smooth' }); }
function focusSearch() { document.getElementById('search-input').focus(); document.getElementById('search-input').scrollIntoView({ behavior: 'smooth' }); }

// ============================================================
// UI 辅助
// ============================================================
function showLoading(show) { document.getElementById('loading-indicator').style.display = show ? 'flex' : 'none'; }
function showError(msg) { const el = document.getElementById('error-message'); el.textContent = msg; el.style.display = 'block'; }
function hideError() { document.getElementById('error-message').style.display = 'none'; }
