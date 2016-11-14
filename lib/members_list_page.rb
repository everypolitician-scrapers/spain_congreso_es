# frozen_string_literal: true
require_relative 'spanish_congress_page'

class MembersListPage < SpanishCongressPage
  def member_urls
    @member_urls ||= noko.css('div#RESULTADOS_DIPUTADOS div.listado_1 ul li a').map { |p| p[:href] }
  end

  def next_page_url
    next_page_link && next_page_link[:href]
  end

  def next_page_link
    @next_page_url ||= noko.css('//div[@class = "paginacion"]//a[contains("Página Siguiente")]').first
  end
end
