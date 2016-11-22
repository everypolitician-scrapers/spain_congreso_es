class RemoveSessionInformationFromLinks < Scraped::Response::Decorator
  def body
    doc = Nokogiri::HTML(response.body)
    doc.css('a').each do |link|
      link[:href] = url_without_session_info(link[:href])
    end
    doc.to_s
  end

  private

  def url_without_session_info(url)
    uri = URI.parse(url.to_s)
    return uri.to_s unless uri.query
    uri.query = uri.query.gsub(/_piref[\d_]+\./, '')
    uri.to_s
  end
end
