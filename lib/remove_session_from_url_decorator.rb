# frozen_string_literal: true
require 'uri'

class RemoveSessionFromUrlDecorator < Scraped::Response::Decorator
  # Remove session information from urls
  def body
    noko = Nokogiri::HTML(super)
    noko.css('a[href*="_piref"]').each do |a|
      uri = URI.parse(a[:href])
      uri.query = uri.query.gsub(/_piref[\d_]+\./, '')
      a[:href] = uri.to_s
    end
    noko.to_s
  end
end
