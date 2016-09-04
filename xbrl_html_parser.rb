class XbrlHtmlParser

	def parse_to_map(html, charset, xbrl_names_list, xbrl_attrs_list)
		doc = Nokogiri::HTML.parse(html, nil, charset)
		doc.remove_namespaces!
		map = {}
		xbrl_names_list.each{|xbrl_names|
			xbrl_names.each{|xbrl_name|
				doc_xpath = doc.xpath("//*[@name=\"jppfs_cor:#{xbrl_name}\"]")
        if doc_xpath.empty?
					doc_xpath = doc.xpath("//*[@name=\"tse-ed-t:#{xbrl_name}\"]")
				end
        doc_xpath.each{|i|
					xbrl_attrs_list.each{|xbrl_attrs|
						if !xbrl_attrs.include?(i.attribute("contextref").text)
							next
						end
						nilable_sign = i.attribute("sign")
						if nilable_sign == nil
							sign = 1
						else
							sign = -1
						end
						value = i.text
						scale = 0
						if i.attribute("scale") != nil
							scale = i.attribute("scale").value
						end
						map["#{xbrl_names[0]}:#{xbrl_attrs[0]}"] = sign * (value.gsub(/(\d{0,3}),(\d{3})/, '\1\2').to_f * (10 ** scale.to_f))
					}
				}
			}
		}
		map
	end

end