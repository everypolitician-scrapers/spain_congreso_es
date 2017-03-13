# Each member has a profile page and a list of memberships.
# The most recent membership for a given member is captured
# from the profile page. Additional memberships are captured
# separately.

# frozen_string_literal: true
require 'scraperwiki'
require 'pry'
require_relative 'lib/members_list_page'
require_relative 'lib/member_page'
require_relative 'lib/membership_list'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

def scrape(h)
  url, klass = h.to_a.first
  klass.new(response: Scraped::Request.new(url: url).response)
end

def member_urls(url, urls = [])
  page = scrape(url => MembersListPage)
  urls += page.member_urls
  return urls if page.next_page_url.nil?
  member_urls(page.next_page_url, urls)
end

# Get a list of URLs for all the members listed.
members_list = 'http://www.congreso.es/portal/page/portal/Congreso/Congreso/Diputados/DiputadosTodasLegislaturas'
urls = member_urls(members_list).uniq
puts "Found #{urls.count} member pages."

# Rejects fields not to be merged with `other_memberships`.
def person_data(data)
  unwanted_keys = %i(party faction faction_id start_date end_date constituency term)
  data.reject do |k, _v|
    unwanted_keys.include? k
  end
end

# Scrape the profile page for each member. (`latest_membership`)
# Scrape the 'Todas las legislaturas' list of each member. (`other_memberships`)
# Merge each 'other_membership' (dropping the membership listed on the profile page)
# with data from the profile page. (`all_memberships`)
# Add the membership captured from the profile page to `all_memberships`
count = 0
merged_memberships = urls.flat_map do |url|
  puts count += 1
  latest_membership = scrape(url => MemberPage).to_h
  other_memberships = MembershipList.new(latest_membership[:source]).memberships.map(&:to_h).drop(1)
  all_memberships = other_memberships.map do |mem|
    mem.merge(person_data(latest_membership))
  end
  all_memberships.push latest_membership
end

ScraperWiki.sqliteexecute('DELETE FROM data') rescue nil
merged_memberships.each do |mem|
  ScraperWiki.save_sqlite(%i(name iddiputado term), mem)
end
