# frozen_string_literal: true
require 'scraperwiki'
require 'uri'
require 'pry'
require 'require_all'
require_rel 'lib'

url = 'http://www.congreso.es/portal/page/portal/Congreso/Congreso/Diputados/DiputadosTodasLegislaturas'

loop do
  page = MembersListPage.new(response: ScrapedPage::Request.new(url: url).response([AbsoluteLinks.new, RemoveSessionInformationFromLinks.new]))
  page.member_urls.each do |member_url|
    member = MemberPage.new(response: ScrapedPage::Request.new(url: member_url).response([AbsoluteLinks.new, RemoveSessionInformationFromLinks.new]))
    ScraperWiki.save_sqlite([:name, :term], member.to_h)
  end
  url = page.next_page_url
  break if url.nil?
end
