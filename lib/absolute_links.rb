class AbsoluteLinks
  def initialize(base_url:)
    @base_url = base_url
  end

  def call(response)
    doc = Nokogiri::HTML(response.body)
    doc.css('a').each do |link|
      next if link[:href].to_s.strip.empty?
      next if link[:href].start_with?('http:')
      next if link[:href].start_with?('mailto:')
      link[:href] = URI.join(base_url, URI.encode(URI.decode(link[:href]))).to_s
    end
    ScrapedPage::Response.new(body: doc.to_s, status: response.status, url: response.url, headers: response.headers)
  end

  private

  attr_reader :base_url
end
