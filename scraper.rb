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

    bio, other = details.css('div.texto_dip')
    seat, faction = bio.css('ul li div.dip_rojo').map(&:text).map(&:tidy)

    contacts = bio.css('div.webperso_dip')
    email = contacts.xpath('..//a[@href[contains(.,"mailto")]]').text.tidy
    twitter = contacts.xpath('..//a[@href[contains(.,"twitter")]]/@href').text.tidy

    data = {
        id: url.to_s[/idDiputado=(\d+)/, 1],
        name: "#{given_names} #{family_names}",
        sort_name: name,
        given_name: given_names,
        family_name: family_names,
        gender: gender_from(seat),
        faction: faction,
        party: person.css('div#datos_diputado p.nombre_grupo').text.tidy,
        source: url.to_s,
        dob: date_of_birth(other.css('ul li').first.text.tidy),
        term: term,
        email: email,
        twitter: twitter,
        photo: person.css('div#datos_diputado p.logo_grupo img[name=foto]/@src').text,
        constituency: seat,
    }
    data[:photo] = URI.join(url, data[:photo]).to_s unless data[:photo].to_s.empty?

    # puts "%s - %s - %s - %s\n" % [ data[:name], data[:dob], data[:constituency], data[:gender], data[:twitter] ]
    ScraperWiki.save_sqlite([:id, :term], data)
end

(1..11).reverse_each do |term, url|
  puts term
  url = 'http://www.congreso.es/portal/page/portal/Congreso/Congreso/Diputados?_piref73_1333056_73_1333049_1333049.next_page=/wc/menuAbecedarioInicio&tipoBusqueda=completo&idLegislatura=%d' % term
  scrape_term(term, url)
end
