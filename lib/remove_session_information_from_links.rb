class RemoveSessionInformationFromLinks
  def call(response)
    doc = Nokogiri::HTML(response.body)
    doc.css('a').each do |link|
      link[:href] = url_without_session_info(link[:href])
    end
    ScrapedPage::Response.new(body: doc.to_s, status: response.status, url: response.url, headers: response.headers)
  end

  private

  # Remove session information from url
  def url_without_session_info(url)
    uri = URI.parse(url.to_s)
    return uri.to_s unless uri.query
    uri.query = uri.query.gsub(/_piref[\d_]+\./, '')
    uri.to_s
  end
end
