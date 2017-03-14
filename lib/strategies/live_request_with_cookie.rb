require 'scraped'

class LiveRequestWithCookie < Scraped::Request::Strategy::LiveRequest
  def response
    log "Fetching #{url}"
    response = open(url, 'Cookie' => config[:cookie])
    {
      status:  response.status.first.to_i,
      headers: response.meta,
      body:    response.read,
    }
  end
end
