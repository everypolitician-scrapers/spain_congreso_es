# frozen_string_literal: true
require 'scraperwiki'
require 'uri'
require_relative 'lib/members_list_page'
require_relative 'lib/member_page'
require_relative 'lib/spanish_congress_request'
require 'pry'

url = 'http://www.congreso.es/portal/page/portal/Congreso/Congreso/Diputados/DiputadosTodasLegislaturas'

loop do
  page = MembersListPage.new(response: SpanishCongressRequest.new(url: url).response)
  page.member_urls.each do |member_url|
    member = MemberPage.new(response: SpanishCongressRequest.new(url: URI.join(url, member_url)).response)
    ScraperWiki.save_sqlite([:name, :term], member.to_h)
  end
  url = page.next_page_url
  break if url.nil?
end
