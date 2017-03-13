# frozen_string_literal: true
require 'capybara'
require 'capybara/poltergeist'
require 'field_serializer'
require_relative 'membership.rb'

class MembershipList
  include FieldSerializer

  def initialize(url)
    @url = url
    setup_capybara
  end

  field :memberships do
    browser = Capybara.current_session
    # The scraper needs to visit the member profile page
    # first, otherwise the membership list will not load
    browser.visit url
    # Vist the membership list and create a Membership
    # object for each membership listed.
    browser.visit url.gsub('fichaDiputado&', 'listadoFichas?')
    browser.all('.all_leg').map do |membership|
      Membership.new(membership)
    end
  end

  private

  attr_reader :url

  def setup_capybara
    options = {
      js_errors:         false,
      timeout:           120,
      phantomjs_options: ['--load-images=no'],
    }

    Capybara.register_driver :poltergeist do |app|
      Capybara::Poltergeist::Driver.new(app, options)
    end

    Capybara.default_driver = :poltergeist
  end
end
