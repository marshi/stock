class Elasticsearch

  @host
  @port

  def initialize
    @host = "localhost"
    @port = "9200"
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
      type_map[type]["properties"][item[0]] = {
          "type" => "number",
          "index" => "not_analyzed"
      }
    }
    type_map
  end

  def create_type(json)
    conn = Faraday::Connection.new(:url => "http://#{@host}:#{@port}") do |builder|
      builder.use Faraday::Request::UrlEncoded
      # builder.use Faraday::Response::Logger
      builder.use Faraday::Adapter::NetHttp
    end
    conn.put "/stock", json
  end

  def post(type, json)
    conn = Faraday::Connection.new(:url => "http://#{@host}:#{@port}") do |builder|
      builder.use Faraday::Request::UrlEncoded
      # builder.use Faraday::Response::Logger
      builder.use Faraday::Adapter::NetHttp
    end
    res = conn.post "/stock/#{type}/", json
  end

end