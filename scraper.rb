#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri/cached'
require 'pry'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_term(term, url)
  page = noko_for url

  term_details = page.css('div.TITULO_CONTENIDO').text.tidy
  matched = term_details.match('(^[^\(]*)\s+\(([^\)]*)\)')
  if matched
    term_name, dates = matched.captures
    matched_dates = dates.match('(\d+)\s*-\s*(.*)')
    if matched_dates
      start_date, end_date = matched_dates.captures
    end
  end

  data = {
      id: term,
      name: term_name.tidy,
      source: url.to_s,
      start_date: start_date.tidy,
  }

  if end_date.tidy != 'Actualidad'
    data[:end_date] = end_date.tidy
  end

  ScraperWiki.save_sqlite([:id], data, 'terms')
  scrape_people(term, url)
end

def scrape_people(term, url)
  page = noko_for url

  page.css('div#RESULTADOS_DIPUTADOS div.listado_1 ul li a/@href').each do |href|
    scrape_person(term, URI.join(url, href))
  end

  pagination = page.css('div.paginacion').first
  next_page = pagination.xpath(".//a[contains(.,'Página Siguiente')]/@href")
  unless next_page[0].nil?
    scrape_people(term, next_page[0].value)
  end
end

def month(str)
  ['','enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'].find_index(str) or raise "Unknown month #{str}".magenta
end

def date_of_birth(str)
  matched = str.match(/(\d+) de ([^[:space:]]*) de (\d+)/) or return
  day, month, year = matched.captures
  "%d-%02d-%02d" % [ year, month(month), day ]
end

def gender_from(seat)
  return 'female' if seat.include? 'Diputada'
  return 'male' if seat.include? 'Diputado'
  return
end

def scrape_person(term, url)
    person = noko_for(url)

    details = person.css('div#curriculum')

    name = details.css('div.nombre_dip').text
    family_names, given_names = name.split(/,/).map(&:tidy)

    seat, group = details.css('div.texto_dip ul li div.dip_rojo').map(&:text).map(&:tidy)
    faction, faction_id = group.match(/(.*?) \((.*?)\)/).captures.to_a.map(&:tidy) rescue nil

    unless (fecha_alta = person.xpath('.//div[@class="dip_rojo"][contains(.,"Fecha alta")]')).empty?
      start_date = fecha_alta.text.match(/(\d+)\/(\d+)\/(\d+)\./).captures.reverse.join("-")
    end

    unless (causo_baja = person.xpath('.//div[@class="dip_rojo"][contains(.,"Causó baja")]')).empty?
      end_date = causo_baja.text.match(/(\d+)\/(\d+)\/(\d+)\./).captures.reverse.join("-")
    end

    data = {
        id: url.to_s[/idDiputado=(\d+)/, 1],
        name: "#{given_names} #{family_names}",
        sort_name: name,
        given_name: given_names,
        family_name: family_names,
        gender: gender_from(seat),
        party: person.css('div#datos_diputado p.nombre_grupo').text.tidy,
        faction_id: faction_id,
        faction: faction,
        source: url.to_s,
        dob: date_of_birth(person.css('div.titular_historico').xpath('following::div/ul/li').text),
        term: term,
        start_date: start_date,
        end_date: end_date,
        email: person.css('div.webperso_dip a[href*="mailto"]').text.tidy,
        twitter: person.css('div.webperso_dip a[href*="twitter.com"]/@href').text,
        facebook: person.css('div.webperso_dip a[href*="facebook.com"]/@href').text,
        phone: person.css('div.texto_dip').text.match(/Teléfono: (.*)$/).to_a.last.to_s.tidy,
        fax: person.css('div.texto_dip').text.match(/Fax: (.*)$/).to_a.last.to_s.tidy,
        photo: person.css('div#datos_diputado p.logo_grupo img[name=foto]/@src').text,
        constituency: seat[/Diputad. por (.*)\./, 1],
    }
    data[:photo] = URI.join(url, data[:photo]).to_s unless data[:photo].to_s.empty?

    # puts "%s - %s - %s - %s - F:%s\n" % [ data[:name], data[:dob], data[:constituency], data[:gender], data[:facebook] ]
    ScraperWiki.save_sqlite([:id, :term], data)
end

# (1..11).reverse_each do |term, url|
  term = 11
  url = 'http://www.congreso.es/portal/page/portal/Congreso/Congreso/Diputados?_piref73_1333056_73_1333049_1333049.next_page=/wc/menuAbecedarioInicio&tipoBusqueda=completo&idLegislatura=%d' % term
  scrape_term(term, url)
# end
