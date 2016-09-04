class XbrlParser

  def parse (html, charset, xbrl_names_list, xbrl_attrs_list)
    doc = Nokogiri::XML.parse(html, nil, charset)
    doc.remove_namespaces!
    map = {}
    xbrl_names_list.each{|xbrl_names|
      xbrl_names.each{|xbrl_name|
        xbrl_attrs_list.each{|xbrl_attrs|
          doc.xpath("//#{xbrl_name}").each{|i|
            if !xbrl_attrs.include?(i.attribute("contextRef").text)
              next
            end
            scale = 0
            if i.attribute("scale") != nil
              scale = i.attribute("scale").value
            end
            map["#{xbrl_names[0]}:#{xbrl_attrs[0]}"] = i.text.gsub(/(\d{0,3}),(\d{3})/, '\1\2').to_f * (10 ** scale.to_f)
          }
        }
      }
    }
    map
  end

end