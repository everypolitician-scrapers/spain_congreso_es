class AbsoluteLinks < ScrapedPage::Processor
  def body
    doc = Nokogiri::HTML(super)
    doc.css('a').each do |link|
      next if link[:href].to_s.strip.empty?
      next if link[:href].start_with?('http:')
      next if link[:href].start_with?('mailto:')
      link[:href] = URI.join(response.url, URI.encode(URI.decode(link[:href]))).to_s
    end
    doc.to_s
  end
end
