require 'scraped_page'
require 'uri'

class SpanishCongressPage < ScrapedPage
  # Remove session information from url
  def url
    uri = URI.parse(super.to_s)
    return uri.to_s unless uri.query
    uri.query = uri.query.gsub(/_piref[\d_]+\./, '')
    uri.to_s
  end
end
