# frozen_string_literal: true
require 'scraperwiki'
require 'pry'
require_relative 'lib/members_list_page'
require_relative 'lib/member_page'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

def scrape(h)
  url, klass = h.to_a.first
  klass.new(response: Scraped::Request.new(url: url).response)
end

def scrape_members(url)
  page = scrape(url => MembersListPage)
  page.member_urls.map do |member_url|
    data = scrape(member_url => MemberPage).to_h
    puts data.reject { |k, v| v.to_s.empty? }.sort_by { |k, v| k }.to_h
    ScraperWiki.save_sqlite([:name, :term], data)
  end
  scrape_members(page.next_page_url) unless page.next_page_url.nil?
end

ScraperWiki.sqliteexecute('DELETE FROM data') rescue nil
scrape_members('http://www.congreso.es/portal/page/portal/Congreso/Congreso/Diputados/DiputadosTodasLegislaturas')
