class XbrlHtmlParser

	def parse_to_map(html, charset, list)

		doc = Nokogiri::HTML.parse(html, nil, charset)
		map = {}
		list.each{|item|
			value_tag_list = doc.xpath("//*[@name=\"#{item}\"]")
			if value_tag_list.empty?
				puts "empty"
				puts item
				next
			end
			nilable_sign = value_tag_list.attribute("sign")
			if nilable_sign == nil
				sign = ""
			else
				sign = nilable_sign.value
			end
			value = value_tag_list[1].text
			map[item] = (sign + value.gsub(/(\d{0,3}),(\d{3})/, '\1\2')).to_i * 1000000
		}
		map
  end

end