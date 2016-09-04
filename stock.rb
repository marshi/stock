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
     "ProfitLossAttributeToOwnerOfParent", #親会社に帰属する当期純利益
     "ProfitAttributableToOwnersOfParent",#親会社株主に帰属する当期純利益
     "IncomeBeforeMinorityInterests" #少数株主損益調整前当期純利益
    ],
    ["SellingGeneralAndAdministrativeExpenses"], #販売管理費及び一般管理費合計
    ["NonOperatingIncome"], #営業外収益合計
    ["IncomeBeforeIncomeTaxes"],
    [ "ProfitLossAttributeToOwnerOfParentSummaryOfBusinessResults", #親会社株主に帰属する当期純利益または親会社株主に帰属する当期純損失
      "NetIncomeLossSummaryOfBusinessResults"
    ],
    ["NetIncomePerShare"], #1株当たり当期純利益
    ["NetCashProvidedByUsedInOperatingActivities"], #営業活動によるキャッシュ・フロー
    ["NetCashProvidedByUsedInInvestmentActivities"], #投資活動によるキャッシュ・フロー
    ["NetCashProvidedByUsedInFinancingActivities"] #財務活動によるキャッシュ・フロー
]

xbrl_attrs_list = [
    ["CurrentYTDConsolidatedDuration",
     "CurrentYearConsolidatedDuration",
     "CurrentQuarterConsolidatedDuration",
     "CurrentAccumulatedQ1ConsolidatedDuration",
     "CurrentAccumulatedQ2ConsolidatedDuration",
     "CurrentAccumulatedQ3ConsolidatedDuration",
     "CurrentAccumulatedQ4ConsolidatedDuration",
     "CurrentAccumulatedQ1Duration_ConsolidatedMember_ResultMember",
     "CurrentAccumulatedQ2Duration_ConsolidatedMember_ResultMember",
     "CurrentAccumulatedQ3Duration_ConsolidatedMember_ResultMember",
     "CurrentAccumulatedQ4Duration_ConsolidatedMember_ResultMember",
     "CurrentYTDDuration",
     "CurrentYearInstant_NonConsolidatedMember",
     "CurrentYearDuration"
    ],
    [ "NextAccumulatedQ1ConsolidatedDuration", #四半期業績予想 親会社株主に帰属する当期純利益
      "NextAccumulatedQ2ConsolidatedDuration",
      "NextAccumulatedQ3ConsolidatedDuration",
      "NextAccumulatedQ4ConsolidatedDuration",
      "NextAccumulatedQ1Duration_ConsolidatedMember_ForecastMember",
      "NextAccumulatedQ2Duration_ConsolidatedMember_ForecastMember",
      "NextAccumulatedQ3Duration_ConsolidatedMember_ForecastMember",
      "NextAccumulatedQ4Duration_ConsolidatedMember_ForecastMember",
    ],
    ["NextYearDuration_ConsolidatedMember_ForecastMember", #通期業績予想 親会社株主に帰属する当期純利益
     "CurrentYearDuration_ConsolidatedMember_ForecastMember"
    ]
]

elasticsearch = Elasticsearch.new
ufocatcher = Ufocatcher.new
xbrl_html_parser = XbrlHtmlParser.new
xbrl_parser = XbrlParser.new

create_type_json = elasticsearch.create_type_json("profit_and_loss", xbrl_list, xbrl_attrs_list)
elasticsearch.create_type(create_type_json.to_json)
charset = nil

def diff(prev_map, map)
  diff_map = {}
  map.each{|key, value|
    if map[key] != nil && prev_map[key] != nil
      diff_map[key + "_diff"] =  map[key].to_i - prev_map[key].to_i
      diff_map[key + "_diff_%"] = (map[key].to_f / prev_map[key].to_f) * 100
    end
  }
  diff_map
end

stock_codes.each{|code|
  xbrl_hash = ufocatcher.convert_to_xbrl(code)
  if xbrl_hash.empty?
    next
  end
  xbrl_hash = Hash[xbrl_hash.sort_by { |k,_| Date.strptime(k,"%Y/%m/%d") }]

  prev_map = {}
  xbrl_hash.each{|day, info|
    pp day
    map = {}
    info.url_list.each{|url_info|
      # if url_info.url != "http://resource.ufocatch.com/xbrl/tdnet/TD2015111300058/2015/11/13/081220150908493331/XBRLData/Summary/tse-acedjpsm-74940-20150908493331-ixbrl.htm"
      #   next
      # end
      if info.type == :old_xbrl #XBRLファイル対象のパース
        html = open(url_info.url) do |f|
          charset = f.charset # 文字種別を取得
          f.read # htmlを読み込んで変数htmlに渡す
        end
        map.merge!(xbrl_parser.parse(html, charset, xbrl_list, xbrl_attrs_list))
      else
        info.url_list.each{|url_info|
          html = open(url_info.url) do |f|
            charset = f.charset # 文字種別を取得
            f.read # htmlを読み込んで変数htmlに渡す
          end
          tmp_map = xbrl_html_parser.parse_to_map(html, charset, xbrl_list, xbrl_attrs_list)
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
    elasticsearch.post("profit_and_loss", map.to_json)
    prev_map = map
  }
}
