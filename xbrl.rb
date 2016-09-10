class Xbrl
  attr_accessor :url_list, :type

  def initialize

  end

  @url_list = []

end

class UrlInfo

  attr_accessor :url, :day, :type

  @url
  @day
  #anplとか
  @type

  def initialize(url, type)
    @url = url
    year, month, day = day_parse(url)
    @day = "#{year}/#{sprintf("%02d", month)}/#{sprintf("%02d", day)}"
    @type = type
  end

  private
  def day_parse(url)
    m = url.match(/http:\/\/resource.ufocatch.com\/xbrl\/tdnet\/.*\/(\d{4})\/(\d{1,2})\/(\d{1,2})\/.*/)
    year = m[1]
    month = m[2]
    day = m[3]
    return year, month, day
  end
end