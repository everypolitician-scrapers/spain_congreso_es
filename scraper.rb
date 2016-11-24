# frozen_string_literal: true
require 'scraperwiki'
require 'pry'
require 'require_all'
require_rel 'lib'

url = 'http://www.congreso.es/portal/page/portal/Congreso/Congreso/Diputados/DiputadosTodasLegislaturas'

loop do
  page = MembersListPage.new(response: Scraped::Request.new(url: url).response(decorators: [ArchiveDecorator, AbsoluteLinks, RemoveSessionInformationFromLinks]))
  page.member_urls.each do |member_url|
    member = MemberPage.new(response: Scraped::Request.new(url: member_url).response(decorators: [ArchiveDecorator, AbsoluteLinks, RemoveSessionInformationFromLinks]))
    ScraperWiki.save_sqlite([:name, :term], member.to_h)
  end
  url = page.next_page_url
  break if url.nil?
end
