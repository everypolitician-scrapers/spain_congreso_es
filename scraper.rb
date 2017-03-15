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

def unmerged_memberships(url)
  page = scrape(url => MembersListPage)
  page.member_urls.map do |member_url|
    puts "Scraping unmerged: #{member_url}"
    data = scrape(member_url => MemberPage).to_h
    puts data[:memberships_list].memberships.map(&:to_h)
    data
  end
  unmerged_memberships(page.next_page_url) unless page.next_page_url.nil?
end

def person_data(data)
  unwanted_keys = %i(party faction faction_id start_date end_date constituency term memberships_list)
  data.reject do |k, _v|
    unwanted_keys.include? k
  end
end

member_list_url = 'http://www.congreso.es/portal/page/portal/Congreso/Congreso/Diputados/DiputadosTodasLegislaturas'
merged_memberships = unmerged_memberships(member_list_url).flat_map do |mem|
  other_memberships = mem[:memberships_list].memberships.reject{ |other_m| other_m.term == mem[:term] }
  all_memberships = other_memberships.map do |other_m|
    other_m.to_h.merge(person_data(mem))
  end
  mem.delete(:memberships_list)
  all_memberships.push mem
end

ScraperWiki.sqliteexecute('DELETE FROM data') rescue nil
merged_memberships.each do |mem|
  ScraperWiki.save_sqlite([:name, :term], mem)
end
