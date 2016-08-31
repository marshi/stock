class XbrlParser

  def parse (html, charset, list)
    doc = Nokogiri::XML.parse(html, nil, charset)
    doc.remove_namespaces!
    map = {}
    list.each{|item|
      doc.xpath("//#{item}").each{|i|
        if i.attribute("contextRef").text != "CurrentYTDConsolidatedDuration" &&
            i.attribute("contextRef").text != "CurrentYearConsolidatedDuration" &&
            i.attribute("contextRef").text != "CurrentQuarterConsolidatedDuration" &&
            i.attribute("contextRef").text != "CurrentAccumulatedQ1ConsolidatedDuration" &&
            i.attribute("contextRef").text != "CurrentAccumulatedQ2ConsolidatedDuration" &&
            i.attribute("contextRef").text != "CurrentAccumulatedQ3ConsolidatedDuration" &&
            i.attribute("contextRef").text != "CurrentAccumulatedQ4ConsolidatedDuration"
          next
        end
        map[item] = i.text
      }
    }
    map
  end

end