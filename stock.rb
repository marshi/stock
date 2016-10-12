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
require_relative 'kdb'
require_relative 'stock_price'

stock_codes = [
   8125
]

xbrl_list = [
    ["CostOfSales"], #売上原価
    ["NetSales"], #売上高合計
    ["NetAssets"], #純資産
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
    ["NetAssetsPerShare"], #一株あたり純資産
    ["NetCashProvidedByUsedInOperatingActivities"], #営業活動によるキャッシュ・フロー
    ["NetCashProvidedByUsedInInvestmentActivities"], #投資活動によるキャッシュ・フロー
    ["NetCashProvidedByUsedInFinancingActivities"], #財務活動によるキャッシュ・フロー
    ["NumberOfIssuedAndOutstandingSharesAtTheEndOfFiscalYearIncludingTreasuryStock"], #発行済株式数
    ["OtherComprehensiveIncome"], # その他包括利益合計
    ["CapitalAdequacyRatio"] #自己資本比率
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
    ["CurrentAccumulatedQ1Instant_ConsolidatedMember_ResultMember",
     "CurrentAccumulatedQ2Instant_ConsolidatedMember_ResultMember",
     "CurrentAccumulatedQ3Instant_ConsolidatedMember_ResultMember",
     "CurrentAccumulatedQ4Instant_ConsolidatedMember_ResultMember",
     "CurrentYearInstant_ConsolidatedMember_ResultMember",
     "CurrentYearConsolidatedInstant"
    ],
    ["CurrentYearInstant_NonConsolidatedMember_ResultMember",
     "CurrentAccumulatedQ1Instant_NonConsolidatedMember_ResultMember",
     "CurrentAccumulatedQ2Instant_NonConsolidatedMember_ResultMember",
     "CurrentAccumulatedQ3Instant_NonConsolidatedMember_ResultMember",
     "CurrentAccumulatedQ4Instant_NonConsolidatedMember_ResultMember"
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

kdb = Kdb.new
elasticsearch = Elasticsearch.new
ufocatcher = Ufocatcher.new
xbrl_html_parser = XbrlHtmlParser.new
xbrl_parser = XbrlParser.new

create_type_json = elasticsearch.create_type_json("profit_and_loss", xbrl_list, xbrl_attrs_list)
elasticsearch.create_type("stock", create_type_json.to_json)

create_day_json = elasticsearch.create_day_json("profit_and_loss")
elasticsearch.create_type("price", create_day_json.to_json)

charset = nil
def diff(prev_map, map, is_quarter, suffix)
  if prev_map == nil || map == nil
    return map
  end
  diff_map = {}
  map.each{|key, value|
    if key.is_a?(Symbol)
      next
    end
    if map[:q1] && !is_quarter
      diff_map[key + suffix] = value
    else
      if map[key] != nil && prev_map[key] != nil
        diff_map[key + suffix] =  map[key].to_i - prev_map[key].to_i
        if prev_map[key + suffix] != nil && prev_map[key + suffix] != 0
          diff_map[key + suffix + "_%"] = (diff_map[key + suffix].to_f / prev_map[key + suffix].to_f) * 100
        end
      end
    end
  }
  diff_map
end

# year_monthより前で最新のデータを取得する.
def latest_stock(map, year_month_date)
  m = map.select{|k, v|
    k.to_i < year_month_date.to_i
  }
  map[m.max[0]]
end

def roe_compute(map)
  other_comprehensive_income = map["OtherComprehensiveIncome-CurrentYTDConsolidatedDuration"].to_i
  net_assets = map["NetAssets-CurrentAccumulatedQ1Instant_ConsolidatedMember_ResultMember"].to_i
  profit_loss = map["ProfitLoss-CurrentYTDConsolidatedDuration"].to_i
  owned_capital = other_comprehensive_income + net_assets
  roe = nil
  if owned_capital != nil && owned_capital != 0
    roe = profit_loss.to_f / owned_capital.to_f * 100
  end
  roe
end

stock_codes.each{|code|
  xbrl_hash = ufocatcher.convert_to_xbrl(code)
  if xbrl_hash.empty?
    next
  end
  xbrl_hash = Hash[xbrl_hash.sort_by { |k,_| Date.strptime(k,"%Y/%m/%d") }]

  year_month_date_map = {}
  prev_map = {}
  prev_month_map = {}
  xbrl_hash.each{|day, info|
    pp day
    year_month_date = day.match(/(\d{4})\/(\d{2})\/(\d{2})/)
    year = year_month_date[1]
    month = year_month_date[2]
    date = year_month_date[3]
    # if !(day =~ /.*2016.*/)
    #    next
    # end
    map = {}
    info.url_list.each{|url_info|
      # if url_info.url != "http://resource.ufocatch.com/xbrl/tdnet/TD2014013000159/2014/1/30/081220140127092370/XBRLData/Summary/tse-qcedjpsm-47510-20140127092370-ixbrl.htm"
      #   next
      # end
      if url_info.type == :old_xbrl #XBRLファイル対象のパース
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
    diff_map = diff(prev_map, map, false, "_diff")
    map.merge!(diff_map)
    diff_map = diff(prev_month_map[month], map, true, "_diff_Q")
    map.merge!(diff_map)
    roe = roe_compute(map)
    map["day"] = day
    map["code"] = code
    map["roe"] = roe
    elasticsearch.post("stock", "profit_and_loss", map.to_json)
    prev_map = map
    prev_month_map[month] = map
    year_month_date_map["#{year}#{month}#{date}"] = map
  }

  price_list = kdb.price_list(code, 2014, 2015, 2016)
  price_list.each{|p|
    per = nil
    year_month_date = p.day.gsub(/(\d{4})\/(\d{2})\/(\d{2})/, '\1\2\3')
    latest_stock = latest_stock(year_month_date_map, year_month_date)
    #PER
    net_income_per_share = latest_stock["NetIncomePerShare-NextYearDuration_ConsolidatedMember_ForecastMember"].to_f
    if net_income_per_share != nil && net_income_per_share != 0
      per = p.price / net_income_per_share
    end

    #PBR
    stock_number = latest_stock["NumberOfIssuedAndOutstandingSharesAtTheEndOfFiscalYearIncludingTreasuryStock-CurrentYearInstant_NonConsolidatedMember_ResultMember"].to_i
    net_assets = latest_stock["NetAssets-CurrentAccumulatedQ1Instant_ConsolidatedMember_ResultMember"].to_f
    net_assets_per_share = nil
    if stock_number != nil && stock_number != 0
      net_assets_per_share = net_assets / stock_number
    end
    pbr = nil
    if net_assets_per_share != nil && net_assets_per_share != 0
      pbr = p.price / net_assets_per_share
    end

    #実質PER
    substantial_per = nil
    if stock_number != nil && stock_number != 0
      ordinary_income = latest_stock["OrdinaryIncome-CurrentYTDConsolidatedDuration"].to_f * 0.6 / stock_number
      if ordinary_income != nil && ordinary_income != 0
        substantial_per = p.price / (ordinary_income)
      end
    end
    price_map = {:day => p.day, :code => code, :price => p.price, :per => per, :pbr => pbr, :substantial_per => substantial_per}
    elasticsearch.post("price", "profit_and_loss", price_map.to_json)
  }

}
