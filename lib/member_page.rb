# frozen_string_literal: true
require 'scraped'
require_relative 'remove_session_from_url_decorator'
require_relative 'parsed_date_string'
require_relative 'strategies/live_request_with_cookie'
require_relative 'memberships_list'
require_relative 'cookie'

class MemberPage < Scraped::HTML
  decorator Scraped::Response::Decorator::AbsoluteUrls
  decorator RemoveSessionFromUrlDecorator

  field :iddiputado do
    query_string['idDiputado']
  end

  field :term do
    query_string['idLegislatura']
  end

  field :name do
    noko.css('div#curriculum div.nombre_dip').text
  end

  field :family_names do
    name.split(/,/).first.to_s.tidy
  end

  field :given_names do
    name.split(/,/).last.to_s.tidy
  end

  field :gender do
    return 'female' if seat.include? 'Diputada'
    return 'male' if seat.include? 'Diputado'
  end

  field :party do
    noko.at_css('#datos_diputado .nombre_grupo').text.tidy
  end

  field :source do
    url.to_s
  end

  field :dob do
    ParsedDateString.new(
      date_string: noko.xpath('.//div[@class="titular_historico"]/following::div/ul/li').first.text
    ).to_s
  end

  field :faction do
    faction_information[:faction].to_s.tidy
  end

  field :faction_id do
    faction_information[:faction_id].to_s.tidy
  end

  field :start_date do
    start_date = noko.xpath('.//div[@class="dip_rojo"][contains(.,"Fecha alta")]')
                     .text.match(/(\d+)\/(\d+)\/(\d+)\./)
    return if start_date.nil?
    start_date.captures.reverse.join('-')
  end

  field :end_date do
    end_date = noko.xpath('.//div[@class="dip_rojo"][contains(.,"Causó baja")]')
                   .text.match(/(\d+)\/(\d+)\/(\d+)\./)
    return if end_date.nil?
    end_date.captures.reverse.join('-')
  end

  field :email do
    noko.css('.webperso_dip a[href*="mailto"]').text.tidy
  end

  field :twitter do
    noko.css('.webperso_dip a[href*="twitter.com"]').text.tidy
  end

  field :facebook do
    noko.css('.webperso_dip a[href*="facebook.com"]').text.tidy
  end

  field :phone do
    noko.css('.texto_dip').text.match(/Teléfono: (.*)$/).to_a.last.to_s.tidy
  end

  field :fax do
    noko.css('.texto_dip').text.match(/Fax: (.*)$/).to_a.last.to_s.tidy
  end

  field :constituency do
    seat[/Diputad. por (.*)\./, 1]
  end

  field :photo do
    foto = noko.at_css('#datos_diputado img[name="foto"]')
    return if foto.nil?
    foto[:src]
  end

  field :memberships_list do
    cookie = Cookie.new(response)
    req = Scraped::Request.new(url: memberships_url, strategies: [{ strategy: LiveRequestWithCookie, cookie: cookie }])
    MembershipsList.new(response: req.response)
  end

  private

  def query_string
    URI.decode_www_form(URI.parse(url).query).to_h
  end

  def seat
    noko.at_css('div#curriculum div.texto_dip ul li div.dip_rojo:first').text.tidy
  end

  def group
    noko.at_css('div#curriculum div.texto_dip ul li div.dip_rojo:last').text.tidy
  end

  def faction_information
    group.match(/(?<faction>.*?) \((?<faction_id>.*?)\)/) || {}
  end

  def memberships_url
    url.gsub('fichaDiputado&', 'listadoFichas?')
  end
end
