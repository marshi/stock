class XbrlParser

  def parse (html, charset, list)
    doc = Nokogiri::XML.parse(html, nil, charset)
    doc.remove_namespaces!
    map = {}
    list.each{|item|
      doc.xpath("//#{item}").each{|i|
        if i.attribute("contextRef").text != "CurrentYTDConsolidatedDuration"
          next
        end
        map[item] = i.text
      }
    }
    map
  end

end