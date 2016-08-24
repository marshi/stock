class Xbrl
  attr_accessor :url, :type

  def initialize

  end

  @url = []
  @type

end

class UrlInfo

  attr_accessor :url, :day

  def initialize(url)
    @url = url
    year, month, day = day_parse(url)
    @day = "#{year}/#{sprintf("%02d", month)}/#{sprintf("%2d", day)}"
  end

  @url
  @day

  private
  def day_parse(url)
    m = url.match(/http:\/\/resource.ufocatch.com\/xbrl\/tdnet\/.*\/(\d{4})\/(\d{1,2})\/(\d{1,2})\/.*/)
    year = m[1]
    month = m[2]
    day = m[3]
    return year, month, day
  end
end