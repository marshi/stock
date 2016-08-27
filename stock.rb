require 'open-uri'
require 'json'
require "faraday"
require 'nokogiri'
require 'pp'
require_relative 'xbrl'
require_relative 'xbrl_html_parser'
require_relative 'elasticsearch'
require_relative 'ufocatcher'

stock_codes = [
		7494
]

pal_list = [
		"jppfs_cor:NetSales", #売上高合計
		"jppfs_cor:CostOfSales", #売上原価合計
		"jppfs_cor:GrossProfit", #売上純利益
		"jppfs_cor:OperatingIncome", #営業利益
		"jppfs_cor:OrdinaryIncome", #経常利益
		"jppfs_cor:ExtraordinaryLoss", #特別損失合計
		"jppfs_cor:NetIncome", #当期純利益
		"jppfs_cor:SellingGeneralAndAdministrativeExpenses", #販売管理費及び一般管理費合計
		"jppfs_cor:NonOperatingIncome" #営業外収益合計
]

cach_list = [
		"jppfs_cor:IncomeBeforeIncomeTaxes",
		"jppfs_cor:NetCashProvidedByUsedInOperatingActivities", #営業活動によるキャッシュ・フロー
		"jppfs_cor:NetCashProvidedByUsedInInvestmentActivities", #投資活動によるキャッシュ・フロー
		"jppfs_cor:NetCashProvidedByUsedInFinancingActivities" #財務活動によるキャッシュ・フロー
]

elasticsearch = Elasticsearch.new
ufocatcher = Ufocatcher.new
xbrl_html_parser = XbrlHtmlParser.new

create_type_json = elasticsearch.create_type_json("profit_and_loss", pal_list) #.merge(create_type_json("cachflow", cach_list))
elasticsearch.create_type(create_type_json.to_json)
charset = nil

stock_codes.each{|code|
	xbrl_hash = ufocatcher.convert_to_xbrl(code)
	puts xbrl_hash
	#損益計算書
	xbrl_hash[:anpl].url_list.each{|url_info|
		html = open(url_info.url) do |f|
			charset = f.charset # 文字種別を取得
			f.read # htmlを読み込んで変数htmlに渡す
		end
		map = xbrl_html_parser.parse_to_map(html, charset, pal_list)
		map["day"] = url_info.day
		map["code"] = code
		puts map.to_json
		# elasticsearch.post("profit_and_loss", map.to_json)
	}
}
