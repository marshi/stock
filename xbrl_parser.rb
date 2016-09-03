class XbrlParser

  def parse (html, charset, xbrl_names_list)
    doc = Nokogiri::XML.parse(html, nil, charset)
    doc.remove_namespaces!
    map = {}
    xbrl_names_list.each{|xbrl_names|
      xbrl_names.each{|xbrl_name|
        doc.xpath("//#{xbrl_name}").each{|i|
          if i.attribute("contextRef").text != "CurrentYTDConsolidatedDuration" &&
              i.attribute("contextRef").text != "CurrentYearConsolidatedDuration" &&
              i.attribute("contextRef").text != "CurrentQuarterConsolidatedDuration" &&
              i.attribute("contextRef").text != "CurrentAccumulatedQ1ConsolidatedDuration" &&
              i.attribute("contextRef").text != "CurrentAccumulatedQ2ConsolidatedDuration" &&
              i.attribute("contextRef").text != "CurrentAccumulatedQ3ConsolidatedDuration" &&
              i.attribute("contextRef").text != "CurrentAccumulatedQ4ConsolidatedDuration"
            next
          end
          map[xbrl_names[0]] = i.text
        }
      }
    }
    map
  end

end