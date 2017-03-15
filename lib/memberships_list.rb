# frozen_string_literal: true
require 'scraped'
require_relative 'membership_row'

class MembershipsList < Scraped::HTML
  field :memberships do
    noko.css('.all_leg').map do |leg|
      fragment leg => MembershipRow
    end
  end
end
