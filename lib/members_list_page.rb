# frozen_string_literal: true
require 'scraped'
require_relative 'remove_session_from_url_decorator'

class MembersListPage < Scraped::HTML
  decorator Scraped::Response::Decorator::AbsoluteUrls
  decorator RemoveSessionFromUrlDecorator

  field :member_urls do
    noko.css('div#RESULTADOS_DIPUTADOS div.listado_1 ul li a').map { |p| p[:href] }
  end

  field :next_page_url do
    next_page_link && next_page_link[:href]
  end

  private

  def next_page_link
    noko.css('//div[@class = "paginacion"]//a[contains("Página Siguiente")]').first
  end
end
