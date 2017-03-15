class Cookie
  def initialize(response)
    @response = response
  end

  def cookie
    "ORA_WX_SESSION='#{ora_wx_session_cookie}';portal=#{portal_cookie}"
  end

  private

  attr_reader :response

  def ora_wx_session_cookie
    response.headers['set-cookie'].split('SESSION="')[1].split('";').first
  end

  def portal_cookie
    response.headers['set-cookie'].split('portal=')[1].split('; ').first
  end
end
