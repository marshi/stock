class XbrlHtmlParser

	def parse_to_map(html, charset, xbrl_names_list)

		doc = Nokogiri::HTML.parse(html, nil, charset)
		doc.remove_namespaces!
		map = {}
		xbrl_names_list.each{|xbrl_names|
      value_tag_list = []
			xbrl_names.each{|xbrl_name|
				value_tag_list = doc.xpath("//*[@name=\"jppfs_cor:#{xbrl_name}\"]")
				if !value_tag_list.empty?
					break
				end
			}
			if value_tag_list.empty?
				# puts "empty"
				# puts item
				next
			end
			nilable_sign = value_tag_list.attribute("sign")
			if nilable_sign == nil
				sign = ""
			else
				sign = nilable_sign.value
			end
			value = value_tag_list[1].text
			map[xbrl_names[0]] = (sign + value.gsub(/(\d{0,3}),(\d{3})/, '\1\2')).to_i * 1000000
		}
		map
	end

end