class Elasticsearch

  @host
  @port

  def initialize
    @host = "localhost"
    @port = "9200"
  end

  def create_type_json(type, list, attrs_list)
    type_map = create_day_json(type)
    list.each{|item|
      attrs_list.each{|attrs|
        type_map[type]["properties"]["#{item[0]}-#{attrs[0]}"] = {
            "type" => "number",
            "index" => "not_analyzed"
        }
      }
    }
    type_map
  end

  def create_day_json(type)
    {
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
  end

  def create_type(index, json)
    conn = Faraday::Connection.new(:url => "http://#{@host}:#{@port}") do |builder|
      builder.use Faraday::Request::UrlEncoded
      # builder.use Faraday::Response::Logger
      builder.use Faraday::Adapter::NetHttp
    end
    conn.put "/#{index}", json
  end

  def post(index, type, json)
    conn = Faraday::Connection.new(:url => "http://#{@host}:#{@port}") do |builder|
      builder.use Faraday::Request::UrlEncoded
      # builder.use Faraday::Response::Logger
      builder.use Faraday::Adapter::NetHttp
    end
    res = conn.post "/#{index}/#{type}/", json
  end

end