# frozen_string_literal: true
require 'scraped_page'
require_relative 'date_of_birth'
require_relative 'core_ext'

class MemberPage < ScrapedPage
  field :iddiputado do
    query['idDiputado']
  end

  field :term do
    query['idLegislatura']
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
    DateOfBirth.new(
      noko.xpath('.//div[@class="titular_historico"]/following::div/ul/li').first.text
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
    URI.join(url, foto[:src]).to_s
  end

  private

  def seat
    @seat ||= noko.at_css('div#curriculum div.texto_dip ul li div.dip_rojo:first').text.tidy
  end

  def group
    @group ||= noko.at_css('div#curriculum div.texto_dip ul li div.dip_rojo:last').text.tidy
  end

  def query
    @query ||= URI.decode_www_form(URI.parse(url).query).to_h
  end

  def faction_information
    @faction_information ||= group.match(/(?<faction>.*?) \((?<faction_id>.*?)\)/) || {}
  end
end
