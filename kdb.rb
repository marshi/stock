class Kdb

  def price_list(code, *years)
    list = []
    years.each{|year|
      url = "http://k-db.com/stocks/#{code}-T/1d/#{year}?download=csv"
      charset = nil
      csv = open(url) do |f|
        charset = f.charset # 文字種別を取得
        f.read # htmlを読み込んで変数htmlに渡す
      end
      local_list = []
      csv.split("\r\n").each{|line|
        row = line.split(",")
        unless row[0].match(/(\d{4})-(\d{2})-(\d{2})/)
          next
        end
        day = row[0].gsub(/(\d{4})-(\d{2})-(\d{2})/, '\1/\2/\3')
        price = row[4]
        local_list << StockPrice.new(day, price.to_i)
      }
      list << local_list
    }
    list.flatten
  end

end