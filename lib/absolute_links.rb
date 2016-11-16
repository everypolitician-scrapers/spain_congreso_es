class AbsoluteLinks < ScrapedPage::Processor
  def body
    doc = Nokogiri::HTML(super)
    doc.css('a').each do |link|
      next if link[:href].to_s.strip.empty?
      next if link[:href].start_with?('http:')
      next if link[:href].start_with?('mailto:')
      link[:href] = URI.join(response.url, uri_encode_decode(link[:href])).to_s
    end
    doc.to_s
  end

  private

  def uri_encode_decode(uri)
    URI.encode(URI.decode(uri)).gsub('[', '%5B').gsub(']', '%5D')
  end
end
