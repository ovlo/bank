module main

// Country — 国家信息
pub struct Country {
pub:
	iso2 string
	iso3 string
	name string
	region string
	capital_city string
	longitude f64
	latitude f64
}

// Indicator — 世界银行指标定义
pub struct Indicator {
pub:
	id string
	name string
	category string // 所属类别：economy, population, health, etc.
	description string
	source_note string
}

// DataPoint — 单个年份的数据点
pub struct DataPoint {
pub:
	year int
	value f64
}

// DataRecord — 单个指标/国家的完整数据
pub struct DataRecord {
pub:
	indicator_id string
	indicator_name string
	country_iso3 string
	country_name string
	points []DataPoint
}

// Category — 预定义数据类别
pub struct Category {
pub:
	id string
	name_en string
	name_zh string
	indicators []Indicator
}

// SearchResult — 搜索结果条目
pub struct SearchResult {
pub:
	indicator_id string
	indicator_name string
	category string
	description string
}

// RegionAggregate — 重要国家组织/地区聚合
pub struct RegionAggregate {
pub:
	code string   // WB API 使用的代码（1W, EUU, OED 等）
	label string  // 显示名称
	name_en string
	name_zh string
}

// WorldSummaryItem — 世界/区域概览指标条目
pub struct WorldSummaryItem {
pub:
	indicator_id   string
	indicator_name string
	category       string
	value          f64
	year           int
}

// RegionSummary — 单个区域/组织的概览数据
pub struct RegionSummary {
pub:
	region_code string
	region_name string
	items       []WorldSummaryItem
}

// CacheEntry — 内存缓存条目
struct CacheEntry {
pub:
	data string
	created_at i64 // unix_milli
}

const cache_ttl_ms = 604800000 // 7 days

// 全球概览 — 主页显示的关键指标
const overview_indicators = [
	OverviewIndicator{'NY.GDP.MKTP.CD', 'GDP (current US$)', 'economy'},
	OverviewIndicator{'NY.GDP.MKTP.KD.ZG', 'GDP growth (annual %)', 'economy'},
	OverviewIndicator{'NY.GDP.PCAP.CD', 'GDP per capita (current US$)', 'economy'},
	OverviewIndicator{'SP.POP.TOTL', 'Population, total', 'population'},
	OverviewIndicator{'SP.DYN.LE00.IN', 'Life expectancy at birth (years)', 'health'},
	OverviewIndicator{'EN.ATM.CO2E.KT', 'CO2 emissions (kt)', 'environment'},
	OverviewIndicator{'IT.NET.USER.ZS', 'Internet users (% of population)', 'technology'},
	OverviewIndicator{'NE.TRD.GNFS.ZS', 'Trade (% of GDP)', 'trade'},
	OverviewIndicator{'SE.PRM.ENRR', 'Primary school enrollment (% gross)', 'education'},
]

// 重要国家组织/地区聚合列表（主页概览展示）
const important_regions = [
	RegionAggregate{'1W', 'World', 'World', '世界'},
	RegionAggregate{'EUU', 'EU', 'European Union', '欧盟'},
	RegionAggregate{'OED', 'OECD', 'OECD Members', '经合组织'},
	RegionAggregate{'EAS', 'E.Asia', 'East Asia & Pacific', '东亚与太平洋'},
	RegionAggregate{'ECS', 'Eur.Cent.', 'Europe & Central Asia', '欧洲与中亚'},
	RegionAggregate{'LCN', 'L.America', 'Latin America & Caribbean', '拉丁美洲与加勒比'},
	RegionAggregate{'MEA', 'M.East', 'Middle East & North Africa', '中东与北非'},
	RegionAggregate{'NAC', 'N.America', 'North America', '北美'},
	RegionAggregate{'SAS', 'S.Asia', 'South Asia', '南亚'},
	RegionAggregate{'SSF', 'Sub-Sah.', 'Sub-Saharan Africa', '撒哈拉以南非洲'},
]

// OverviewIndicator — 概览指标定义
pub struct OverviewIndicator {
pub:
	id       string
	name     string
	category string
}

// 预定义类别与指标
const default_categories = [
		Category{
			id: 'economy'
			name_en: 'Economy'
			name_zh: '经济'
			indicators: [
				Indicator{'NY.GDP.MKTP.CD', 'GDP (current US$)', 'economy', 'GDP at market prices in current US dollars', 'World Bank national accounts data'},
				Indicator{'NY.GDP.MKTP.KD.ZG', 'GDP growth (annual %)', 'economy', 'Annual percentage growth rate of GDP', 'World Bank national accounts data'},
				Indicator{'NY.GDP.PCAP.CD', 'GDP per capita (current US$)', 'economy', 'GDP per capita in current US dollars', 'World Bank national accounts data'},
				Indicator{'FP.CPI.TOTL.ZG', 'Inflation, consumer prices (annual %)', 'economy', 'Annual percentage change in consumer prices', 'International Monetary Fund'},
				Indicator{'SL.UEM.TOTL.ZS', 'Unemployment (% of total labor force)', 'economy', 'Unemployment as percentage of total labor force', 'ILO estimates'},
				Indicator{'NY.GNP.PCAP.CD', 'GNI per capita (current US$)', 'economy', 'GNI per capita in current US dollars', 'World Bank'},
				Indicator{'NY.GDP.TOTL.RT.ZS', 'Gross savings (% of GDP)', 'economy', 'Gross savings as percentage of GDP', 'World Bank national accounts data'},
			]
		},
		Category{
			id: 'population'
			name_en: 'Population'
			name_zh: '人口'
			indicators: [
				Indicator{'SP.POP.TOTL', 'Population, total', 'population', 'Total population', 'World Bank population estimates'},
				Indicator{'SP.POP.GROW', 'Population growth (annual %)', 'population', 'Annual population growth rate', 'World Bank population estimates'},
				Indicator{'SP.DYN.CDRT.IN', 'Death rate (per 1,000 people)', 'population', 'Crude death rate per 1,000 people', 'World Bank population estimates'},
				Indicator{'SP.DYN.CBRT.IN', 'Birth rate (per 1,000 people)', 'population', 'Crude birth rate per 1,000 people', 'World Bank population estimates'},
				Indicator{'SP.URB.TOTL.IN.ZS', 'Urban population (% of total)', 'population', 'Urban population as percentage of total', 'World Bank population estimates'},
				Indicator{'SP.DYN.LE00.IN', 'Life expectancy at birth (years)', 'health', 'Life expectancy in years', 'World Bank population estimates'},
				Indicator{'SP.DYN.LE00.MA.IN', 'Life expectancy, male (years)', 'health', 'Male life expectancy in years', 'World Bank population estimates'},
				Indicator{'SP.DYN.LE00.FE.IN', 'Life expectancy, female (years)', 'health', 'Female life expectancy in years', 'World Bank population estimates'},
			]
		},
		Category{
			id: 'health'
			name_en: 'Health'
			name_zh: '健康'
			indicators: [
				Indicator{'SH.DYN.MORT', 'Mortality rate, under-5 (per 1,000 live births)', 'health', 'Under-5 mortality rate', 'UNICEF estimates'},
				Indicator{'SH.XPD.CHEX.GD.ZS', 'Current health expenditure (% of GDP)', 'health', 'Health expenditure as percentage of GDP', 'World Health Organization'},
				Indicator{'SH.XPD.CHEX.PC.CD', 'Current health expenditure per capita (current US$)', 'health', 'Health expenditure per capita', 'World Health Organization'},
				Indicator{'SH.IMM.MEAS', 'Immunization, measles (% of children ages 12-23 months)', 'health', 'Measles immunization rate', 'UNICEF estimates'},
				Indicator{'SH.STA.MALN.ZS', 'Malnutrition prevalence (% of children under 5)', 'health', 'Malnutrition in children under 5', 'UNICEF estimates'},
			]
		},
		Category{
			id: 'education'
			name_en: 'Education'
			name_zh: '教育'
			indicators: [
				Indicator{'SE.PRM.ENRR', 'Primary school enrollment (% gross)', 'education', 'Gross primary school enrollment ratio', 'UNESCO estimates'},
				Indicator{'SE.SEC.ENRR', 'Secondary school enrollment (% gross)', 'education', 'Gross secondary school enrollment ratio', 'UNESCO estimates'},
				Indicator{'SE.TER.ENRR', 'Tertiary school enrollment (% gross)', 'education', 'Gross tertiary school enrollment ratio', 'UNESCO estimates'},
				Indicator{'SE.ADT.LITR.ZS', 'Literacy rate, adult total (% of people ages 15+)', 'education', 'Adult literacy rate', 'UNESCO estimates'},
				Indicator{'SE.PRM.CMPT.ZS', 'Primary completion rate (% of relevant age group)', 'education', 'Primary completion rate', 'UNESCO estimates'},
			]
		},
		Category{
			id: 'environment'
			name_en: 'Environment'
			name_zh: '环境'
			indicators: [
				Indicator{'EN.ATM.CO2E.KT', 'CO2 emissions (kt)', 'environment', 'Carbon dioxide emissions in kilotons', 'World Bank Climate Data'},
				Indicator{'EN.ATM.CO2E.PC', 'CO2 emissions (metric tons per capita)', 'environment', 'Carbon dioxide emissions per capita', 'World Bank Climate Data'},
				Indicator{'AG.LND.FRST.ZS', 'Forest area (% of land area)', 'environment', 'Forest area as percentage of land area', 'FAO estimates'},
				Indicator{'EG.USE.ELEC.KH.PC', 'Electric power consumption (kWh per capita)', 'environment', 'Electric power consumption per capita', 'IEA estimates'},
				Indicator{'EN.ATM.CO2E.KD.GD', 'CO2 intensity (kg per PPP $ of GDP)', 'environment', 'CO2 intensity of GDP', 'World Bank Climate Data'},
			]
		},
		Category{
			id: 'technology'
			name_en: 'Technology'
			name_zh: '科技'
			indicators: [
				Indicator{'IT.NET.USER.ZS', 'Individuals using the Internet (% of population)', 'technology', 'Internet users as percentage of population', 'ITU estimates'},
				Indicator{'IT.CEL.SETS.P2', 'Mobile cellular subscriptions (per 100 people)', 'technology', 'Mobile phone subscriptions per 100 people', 'ITU estimates'},
				Indicator{'IP.JRN.ARTC.SC', 'Scientific and technical journal articles', 'technology', 'Number of scientific journal articles', 'World Bank estimates'},
				Indicator{'GB.XPD.RSDV.GD.ZS', 'Research and development expenditure (% of GDP)', 'technology', 'R&D expenditure as share of GDP', 'UNESCO estimates'},
				Indicator{'IT.NET.BAND.ZS', 'Fixed broadband subscriptions (per 100 people)', 'technology', 'Fixed broadband subscriptions', 'ITU estimates'},
			]
		},
		Category{
			id: 'trade'
			name_en: 'Trade'
			name_zh: '贸易'
			indicators: [
				Indicator{'NE.EXP.GNFS.CD', 'Exports of goods and services (current US$)', 'trade', 'Total exports in current US dollars', 'World Bank national accounts data'},
				Indicator{'NE.IMP.GNFS.CD', 'Imports of goods and services (current US$)', 'trade', 'Total imports in current US dollars', 'World Bank national accounts data'},
				Indicator{'NE.TRD.GNFS.ZS', 'Trade (% of GDP)', 'trade', 'Trade as percentage of GDP', 'World Bank national accounts data'},
				Indicator{'BX.GSR.CCIS.CD', 'ICT service exports (% of service exports, BoP)', 'trade', 'ICT service exports', 'International Monetary Fund'},
			]
		},
		Category{
			id: 'debt'
			name_en: 'Debt & Finance'
			name_zh: '债务与金融'
			indicators: [
				Indicator{'DT.DOD.DECT.CD', 'External debt stocks, total (current US$)', 'debt', 'Total external debt in current US dollars', 'World Bank International Debt Statistics'},
				Indicator{'DT.INT.DECT.CD', 'Interest payments on external debt (current US$)', 'debt', 'Interest payments on external debt', 'World Bank International Debt Statistics'},
				Indicator{'GC.DOD.TOTL.GD.ZS', 'Central government debt (% of GDP)', 'debt', 'Central government debt as share of GDP', 'IMF estimates'},
				Indicator{'BX.KLT.DINV.WD.GD.ZS', 'Foreign direct investment (% of GDP)', 'debt', 'FDI as percentage of GDP', 'IMF estimates'},
			]
		},
		Category{
			id: 'poverty'
			name_en: 'Poverty & Inequality'
			name_zh: '贫困与不平等'
			indicators: [
				Indicator{'SI.POV.DDAY', 'Poverty headcount ratio at $2.15 a day (PPP, % of population)', 'poverty', 'Extreme poverty rate at $2.15/day', 'World Bank estimates'},
				Indicator{'SI.POV.GINI', 'GINI index', 'poverty', 'Gini index of income inequality', 'World Bank estimates'},
				Indicator{'SI.DST.FRST.10', 'Income share held by highest 10%', 'poverty', 'Income share of richest 10%', 'World Bank estimates'},
				Indicator{'SI.DST.FRST.10', 'Income share held by lowest 10%', 'poverty', 'Income share of poorest 10%', 'World Bank estimates'},
				Indicator{'NY.GNP.PCAP.PP.CD', 'GNI per capita, PPP (current international $)', 'poverty', 'GNI per capita in PPP terms', 'World Bank estimates'},
			]
		},
	]
