require 'open-uri'
require 'json'
require "faraday"
require 'nokogiri'
require 'pp'
require_relative 'xbrl'

pal_list = [
		"jppfs_cor:NetSales", #売上高合計
		"jppfs_cor:CostOfSales", #売上原価合計
		"jppfs_cor:GrossProfit", #売上純利益
		"jppfs_cor:OperatingIncome", #営業利益
		"jppfs_cor:OrdinaryIncome", #経常利益
		"jppfs_cor:ExtraordinaryLoss", #特別損失合計
		"jppfs_cor:ProfitLoss", #当期純利益
		"jppfs_cor:SellingGeneralAndAdministrativeExpenses", #販売管理費及び一般管理費合計
		"jppfs_cor:NonOperatingIncome" #営業外収益合計
]

cach_list = [
		"jppfs_cor:IncomeBeforeIncomeTaxes",
		"jppfs_cor:NetCashProvidedByUsedInOperatingActivities", #営業活動によるキャッシュ・フロー
		"jppfs_cor:NetCashProvidedByUsedInInvestmentActivities", #投資活動によるキャッシュ・フロー
		"jppfs_cor:NetCashProvidedByUsedInFinancingActivities" #財務活動によるキャッシュ・フロー
]

def xbrl_json(list, url)
	charset = nil
	html = open(url) do |f|
		charset = f.charset # 文字種別を取得
		f.read # htmlを読み込んで変数htmlに渡す
	end
	doc = Nokogiri::HTML.parse(html, nil, charset)
	map = {}
	list.each{|item|
		nilable_sign = doc.xpath("//*[@name=\"#{item}\"]").attribute("sign")
		if nilable_sign == nil
			sign = ""
		else
			sign = nilable_sign.value
		end
		value = doc.xpath("//*[@name=\"#{item}\"]")[1].text
		map[item] = (sign + value.gsub(/(\d{0,3}),(\d{3})/, '\1\2')).to_i * 1000000
	}
	map
end

def create_type_json(type, list)
	type_map = {
			type => {
					"properties" => {
							"day" => {
									"type" => "date",
									"format" => "yyyy/mm/dd",
									"index" => "not_analyzed"
							}
					}
			}
	}
	list.each{|item|
		type_map[type]["properties"][item] = {
				"type" => "number",
				"index" => "not_analyzed"
		}
	}
	type_map
end

def create_type(json)
	conn = Faraday::Connection.new(:url => "http://localhost:32846") do |builder|
		builder.use Faraday::Request::UrlEncoded
		# builder.use Faraday::Response::Logger
		builder.use Faraday::Adapter::NetHttp
	end
	res = conn.put "/stock", json
	puts res.body
end

def post(type, json)
	conn = Faraday::Connection.new(:url => "http://localhost:32846") do |builder|
		builder.use Faraday::Request::UrlEncoded
		# builder.use Faraday::Response::Logger
		builder.use Faraday::Adapter::NetHttp
	end
	res = conn.post "/stock/#{type}/", json
	puts res.body
end

def day_parse(url)
	m = url.match(/http:\/\/resource.ufocatch.com\/xbrl\/tdnet\/.*\/(\d{4})\/(\d{1,2})\/(\d{1,2})\/.*/)
	year = m[1]
	month = m[2]
	day = m[3]
	return year, month, day
end

create_type_json = create_type_json("profit_and_loss", pal_list) #.merge(create_type_json("cachflow", cach_list))
create_type(create_type_json.to_json)

#損益計算書
pal_url = "http://resource.ufocatch.com/xbrl/tdnet/TD2016042800219/2016/4/28/081220160421463263/XBRLData/Attachment/0102010-anpl02-tse-anedjpfr-47620-2016-03-31-01-2016-04-28-ixbrl.htm"
map = xbrl_json(pal_list, pal_url)
year, month, day = day_parse(pal_url)
# map["day"] = "#{year}/#{month}/#{day}"
map["day"] = "2016/07/18"
puts map.to_json
post("profit_and_loss", map.to_json)

def cconvert_to_xbrl(stock_code)
	url = "http://resource.ufocatch.com/atom/tdnetx/query/#{stock_code}"
	charset = nil
	html = open(url) do |f|
		charset = f.charset # 文字種別を取得
		f.read # htmlを読み込んで変数htmlに渡す
	end
	doc = Nokogiri::HTML.parse(html, nil, charset)
  xbrl_hash = {}
	doc.css("link").map{|link|
		link.attr("href")
	}.select{|link|
		link.match(/.*ixbrl.htm.*/)
	}.each{|link|
		label = nil
		case link
			when /.*-anpl.*/
				label = :anpl
			when /.*-accf.*/
				label = :accf
			when /.*-anbs.*/
				label = :anbs
			else
				next
		end
		xbrl = xbrl_hash[label] ||= Xbrl.new
		array = xbrl.url ||= []
		array << UrlInfo.new(link)
		xbrl.url = array
		xbrl.type = label
		xbrl_hash[label] = xbrl
	}
  xbrl_hash
end

puts cconvert_to_xbrl(4762)

