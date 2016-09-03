require 'open-uri'
require 'json'
require "faraday"
require 'nokogiri'
require 'pp'
require_relative 'xbrl'
require_relative 'xbrl_html_parser'
require_relative 'xbrl_parser'
require_relative 'elasticsearch'
require_relative 'ufocatcher'

stock_codes = [
    7494
]

xbrl_list = [
    ["CostOfSales"], #売上原価
    ["NetSales"], #売上高合計
    ["CostOfSales"], #売上原価合計
    ["GrossProfit"], #売上純利益
    ["OperatingIncome"], #営業利益
    ["OrdinaryIncome"], #経常利益
    ["ExtraordinaryLoss"], #特別損失合計
    ["ProfitLoss", #四半期純利益
     "NetIncome", #当期純利益
     "ProfitLossAttributeToOwnerOfParent" #親会社に帰属する当期純利益
    ],
    ["SellingGeneralAndAdministrativeExpenses"], #販売管理費及び一般管理費合計
    ["NonOperatingIncome"], #営業外収益合計
    ["IncomeBeforeIncomeTaxes"],
    [ "ProfitLossAttributeToOwnerOfParentSummaryOfBusinessResults", #親会社株主に帰属する当期純利益または親会社株主に帰属する当期純損失
      "NetIncomeLossSummaryOfBusinessResults"
    ],
    ["NetCashProvidedByUsedInOperatingActivities"], #営業活動によるキャッシュ・フロー
    ["NetCashProvidedByUsedInInvestmentActivities"], #投資活動によるキャッシュ・フロー
    ["NetCashProvidedByUsedInFinancingActivities"] #財務活動によるキャッシュ・フロー
]

xbrl_attr_list = [
    ["CurrentYTDConsolidatedDuration",
     "CurrentYearConsolidatedDuration",
     "CurrentQuarterConsolidatedDuration",
     "CurrentAccumulatedQ1ConsolidatedDuration",
     "CurrentAccumulatedQ2ConsolidatedDuration",
     "CurrentAccumulatedQ3ConsolidatedDuration",
     "CurrentAccumulatedQ4ConsolidatedDuration"],
    [ "NextAccumulatedQ1ConsolidatedDuration",
      "NextAccumulatedQ2ConsolidatedDuration",
      "NextAccumulatedQ3ConsolidatedDuration",
      "NextAccumulatedQ4ConsolidatedDuration"
    ]
]

elasticsearch = Elasticsearch.new
ufocatcher = Ufocatcher.new
xbrl_html_parser = XbrlHtmlParser.new
xbrl_parser = XbrlParser.new

create_type_json = elasticsearch.create_type_json("profit_and_loss", xbrl_list)
elasticsearch.create_type(create_type_json.to_json)
charset = nil

def diff(prev_map, map)
  diff_map = {}
  map.each{|key, value|
    if map[key] != nil && prev_map[key] != nil
      diff_map[key + "_diff"] = prev_map[key].to_i - map[key].to_i
      diff_map[key + "_diff_%"] = (prev_map[key].to_f / map[key].to_f) * 100
    end
  }
  diff_map
end

stock_codes.each{|code|
  xbrl_hash = ufocatcher.convert_to_xbrl(code)
  if xbrl_hash.empty?
    next
  end
  prev_map = {}
  xbrl_hash.each{|day, info|
    pp day
    map = {}
    info.url_list.each{|url_info|
      if info.type == :old_xbrl #XBRLファイル対象のパースl
        html = open(url_info.url) do |f|
          charset = f.charset # 文字種別を取得
          f.read # htmlを読み込んで変数htmlに渡す
        end
        map.merge!(xbrl_parser.parse(html, charset, xbrl_list))
      else
        info.url_list.each{|url_info|
          html = open(url_info.url) do |f|
            charset = f.charset # 文字種別を取得
            f.read # htmlを読み込んで変数htmlに渡す
          end
          tmp_map = xbrl_html_parser.parse_to_map(html, charset, xbrl_list)
          map.merge!(tmp_map)
        }
      end
    }
    if map.empty?
      next
    end
    diff_map = diff(prev_map, map)
    map.merge!(diff_map)
    map["day"] = day
    map["code"] = code
    pp map
    elasticsearch.post("profit_and_loss", map.to_json)
    prev_map = map
  }
}
