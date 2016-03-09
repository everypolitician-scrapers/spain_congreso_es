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

# use the first term they were elected in and the id from that term as the unique id
# although for people with only one term the page in question seems to fall over so
# fall back to the current term and id for those people as it's presumably their first
def get_unique_id(url, page_term, page_iddiputado)
    id = ScraperWiki::select('id FROM term_map WHERE iddiputado is ? AND term is ?', [page_iddiputado, page_term]) rescue nil
    unless id.nil?
        return id[:id]
    end

    refs = noko_for(url)

    term_map = {}
    refs.css('div.btn_ficha a/@href').each do |href|
        term, id = href.to_s.match(/idLegislatura=(\d+).*idDiputado=(\d+)/).captures
        term_map[term.to_i] = id
    end

    # the all terms page seems to be very unreliable so if we can't find what we expect
    # then we should quite rather than trying to make up an incorrect ID
    if term_map.empty?
        return nil
    end

    min_term = term_map.keys.min

    id = "#{min_term}_#{term_map[min_term]}"
    for term in term_map.keys
        data = {
            term: term,
            iddiputado: term_map[term],
            id: id,
        }
        ScraperWiki.save_sqlite([:term, :iddiputado], data, 'term_map')
    end
    return id
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

    iddiputado = url.to_s[/idDiputado=(\d+)/, 1]
    all_terms_url = person.css('div.soporte_year li a/@href').text.match('.*listadoFichas.*').to_a.first.to_s
    id = get_unique_id(all_terms_url, term, iddiputado)

    # don't save things f we don't get an id
    if id.nil?
        return
    end

    data = {
        id: id,
        iddiputado: iddiputado,
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

    puts "%s - %s\n" % [ data[:name], data[:id] ]
    ScraperWiki.save_sqlite([:id, :term], data)
end

(1..11).reverse_each do |term, url|
  url = 'http://www.congreso.es/portal/page/portal/Congreso/Congreso/Diputados?_piref73_1333056_73_1333049_1333049.next_page=/wc/menuAbecedarioInicio&tipoBusqueda=completo&idLegislatura=%d' % term
  scrape_term(term, url)
end
