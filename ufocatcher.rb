class Ufocatcher

  def convert_to_xbrl(stock_code)
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
      link.match(/.*ixbrl.*/) || link.match(/.*\.xbrl$/)
    }.each{|link|
      label = nil
      case link
        when /.*-anpl.*/
          label = :anpl
        when /.*-accf.*/
          label = :accf
        when /.*-anbs.*/
          label = :anbs
        when /.*\.xbrl$/
          label = :old_xbrl #xbrlファイル.(たぶん古いデータはxbrlで新しめのデータはxbrl.html)
        else
          next
      end
      xbrl = xbrl_hash[label] ||= Xbrl.new
      array = xbrl.url_list ||= []
      array << UrlInfo.new(link)
      xbrl.url_list = array
      xbrl.type = label
      xbrl_hash[label] = xbrl
    }
    xbrl_hash
  end

end