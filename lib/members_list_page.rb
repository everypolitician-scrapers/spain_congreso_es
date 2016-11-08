require 'scraped_page'

class MembersListPage < ScrapedPage
  def member_urls
    @member_urls ||= noko.css('div#RESULTADOS_DIPUTADOS div.listado_1 ul li a').map { |p| p[:href] }
  end

  def next_page_url
    @next_page_url ||= noko.css('//div[@class = "paginacion"]//a[contains("Página Siguiente")]').first[:href]
  end
end
