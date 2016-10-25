require 'bundler/setup'
require 'pry'
require 'scraped_page_archive'
require 'nokogiri'
require 'scraperwiki'
require_relative './lib/request_response'

DiskStorage = Struct.new(:path)

storage = if ENV.key?('SCRAPED_PAGE_ARCHIVE_REPO')
            DiskStorage.new(ENV['SCRAPED_PAGE_ARCHIVE_REPO'])
          else
            ScrapedPageArchive::GitStorage.new
end

ARCHIVE = ScrapedPageArchive.new(storage)

def noko_for(url)
  puts url
  Nokogiri::HTML(ARCHIVE.open_from_archive(url))
end

class String
  def tidy
    gsub(/[[:space:]]+/, ' ').strip
  end
end

def month(str)
  ['', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'].find_index(str) || raise("Unknown month #{str}".magenta)
end

def date_of_birth(str)
  (matched = str.match(/(\d+) de ([^[:space:]]*) de (\d+)/)) || return
  day, month, year = matched.captures
  '%d-%02d-%02d' % [year, month(month), day]
end

def gender_from(seat)
  return 'female' if seat.include? 'Diputada'
  return 'male' if seat.include? 'Diputado'
  nil
end

def save_membership_from_url(name, url)
  iddiputado = url.to_s.match(/idDiputado=(\d+)/).captures[0]
  term = url.to_s.match(/idLegislatura=(\d+)/).captures[0]
  # strip out session id
  url = url.match(/(.*)_piref[\d_]+\.(next_page.*)/).captures.join('')

  # we can set this to rescrape everything if required
  unless ENV.key?('MORPH_RESCRAPE_ALL')
    #  don't save data again
    cur_name = begin
                 ScraperWiki.select('name FROM memberships WHERE iddiputado is ? AND term is ?', [iddiputado, term])
               rescue
                 nil
               end
    return unless cur_name.nil? || cur_name.empty?
  end

  person = {
    id: 0,
    name: name.tidy,
    term: term,
    iddiputado: iddiputado,
    url: url
  }

  ScraperWiki.save_sqlite([:term, :iddiputado], person, 'memberships')
end

# use the first term they were elected in and the id from that term as the unique id
# although for people with only one term the page in question seems to fall over so
# fall back to the current term and id for those people as it's presumably their first
def get_unique_id(url, page_term, page_iddiputado, name)
  cur_id = begin
             ScraperWiki.select('id FROM memberships WHERE iddiputado is ? AND term is ? and id <> 0', [page_iddiputado, page_term])
           rescue
             nil
           end
  return cur_id[0][:id] unless cur_id.nil? || cur_id.empty?
  sleep(1)

  visit url

  term_map = {}
  all('div.all_leg').each do |legislature|
    within(legislature) do
      term = nil
      if legislature.has_css?('div.btn_ficha a')
        link = find('div.btn_ficha a')
        href = link['href']
        # we can't do this as one operation as they don't always appear
        # in the same order :(
        term = href.to_s.match(/idLegislatura=(\d+)/).captures[0]
        id = href.to_s.match(/idDiputado=(\d+)/).captures[0]
        term_map[term.to_i] = id
        save_membership_from_url(name, href)
      end
      if !term.nil? && legislature.has_css?('div.principal')
        term_div = find('div.principal')
        name, start_year, end_year = term_div.text.match(/(\w+\s*\w+)\s*\(\s*(\d+)\s*-\s*([^)]*)\)/).captures
        end_year = '' if end_year.tidy == 'Actualidad'
        exists = begin
                   ScraperWiki.select('id FROM terms WHERE id is ??', [id])
                 rescue
                   nil
                 end
        if exists.nil?
          term = {
            id: term,
            name: name.tidy,
            start_date: start_year.tidy,
            end_date: end_year.tidy,
            source: 'http://www.congreso.es/'
          }
          ScraperWiki.save_sqlite([:id], term, 'terms')
        end
      end
    end
  end

  # the all terms page seems to be very unreliable so if we can't find what we expect
  # then we should quite rather than trying to make up an incorrect ID
  return nil if term_map.empty?

  min_term = term_map.keys.min

  id = "#{min_term}_#{term_map[min_term]}"
  for term in term_map.keys
    ScraperWiki.sqliteexecute('update memberships set id = ? where id = 0 and term = ? and iddiputado = ?', [id, term, term_map[term]])
  end
  id
end

def scrape_people(url)
  noko = noko_for(url)

  noko.css('div#RESULTADOS_DIPUTADOS div.listado_1 ul li a').each do |link|
    save_membership_from_url(link.text, link['href'])
  end

  pagination = noko.at_css('div.paginacion')
  next_page = nil
  if pagination.xpath(".//a[contains(.,'Página Siguiente')]").any?
    next_page = pagination.at_xpath(".//a[contains(.,'Página Siguiente')]")
  end

  scrape_people(next_page['href']) unless next_page.nil?
end

def scrape_memberships
  memberships = ScraperWiki.select('* FROM memberships')
  for membership in memberships
    scrape_person(membership['term'], membership['url'])
  end
end

def scrape_person(term, url)
  iddiputado = url.to_s[/idDiputado=(\d+)/, 1]

  unless ENV.key?('MORPH_RESCRAPE_ALL') || (ENV.key?('MORPH_RESCRAPE_TERM') && ENV['MORPH_RESCRAPE_TERM'] == term)
    # don't scrape data we already have
    name = begin
             ScraperWiki.select('name FROM data WHERE iddiputado is ? AND term is ?', [iddiputado, term])
           rescue
             nil
           end
    unless name.nil? || name.empty?
      # name = name[0]['name']
      # puts "skipping #{name} for #{term}"
      return
    end
  end
  sleep(1)

  # only visit URL if we are collecting the data
  visit url

  seat, group = all('div#curriculum div.texto_dip ul li div.dip_rojo').map(&:text).map(&:tidy)
  begin
    faction, faction_id = group.match(/(.*?) \((.*?)\)/).captures.to_a.map(&:tidy)
  rescue
    nil
  end

  # sometimes the scraper doesn't find the name on the page and rather than stop scraping
  # everything else just move on to the next person
  begin
    name = find('div#curriculum div.nombre_dip').text
  rescue
    $stderr.puts "failed to find name element for #{url}"
    return
  end

  family_names, given_names = name.split(/,/).map(&:tidy)

  if page.has_xpath?('.//div[@class="dip_rojo"][contains(.,"Fecha alta")]')
    fecha_alta = find(:xpath, './/div[@class="dip_rojo"][contains(.,"Fecha alta")]')
    start_date = fecha_alta.text.match(/(\d+)\/(\d+)\/(\d+)\./).captures.reverse.join('-')
  end

  if page.has_xpath?('.//div[@class="dip_rojo"][contains(.,"Causó baja")]')
    causo_baja = find(:xpath, './/div[@class="dip_rojo"][contains(.,"Causó baja")]')
    end_date = causo_baja.text.match(/(\d+)\/(\d+)\/(\d+)\./).captures.reverse.join('-')
  end

  dob = ''
  email = ''
  twitter = ''
  facebook = ''
  photo = ''
  within('div.titular_historico') do
    dob = date_of_birth(all(:xpath, 'following::div/ul/li')[0].text)
  end

  # capybara doesn't support enough xpath to do this
  # sensibly so we have to do this the longwinded way
  if page.has_xpath?('//div[@class="webperso_dip"]/div[@class="webperso_dip_parte"|@class="webperso_dip_imagen"]/a')
    all(:xpath, '//div[@class="webperso_dip"]/div[@class="webperso_dip_parte"|@class="webperso_dip_imagen"]/a').each do |link|
      href = link['href']
      email = link.text.tidy if href =~ /mailto/
      if href =~ /twitter.com/
        twitter = href.match(/twitter.com\/(.*)$/).captures[0]
      end
      facebook = href if href =~ /facebook.com/
    end
  end

  all('div#datos_diputado').each do |img|
    within(img) do
      if img.has_xpath?('.//p[@class="logo_group"]/img[@name="foto"]')
        photo = find(:xpath, './/p[@class="logo_group"]/img[@name="foto"]')['src'].text
      end
    end
  end

  data = {
    iddiputado: iddiputado,
    name: "#{given_names} #{family_names}",
    sort_name: name,
    given_name: given_names,
    family_name: family_names,
    gender: gender_from(seat),
    party: find('div#datos_diputado p.nombre_grupo').text.tidy,
    faction_id: faction_id,
    faction: faction,
    source: url.to_s,
    dob: dob,
    term: term,
    start_date: start_date,
    end_date: end_date,
    email: email,
    twitter: twitter,
    facebook: facebook,
    phone: all('div.texto_dip').map(&:text).join('').match(/Teléfono: (.*)$/).to_a.last.to_s.tidy,
    fax: all('div.texto_dip').map(&:text).join('').match(/Fax: (.*)$/).to_a.last.to_s.tidy,
    constituency: seat[/Diputad. por (.*)\./, 1],
    photo: photo
  }
  data[:photo] = URI.join(url, data[:photo]).to_s unless data[:photo].to_s.empty?

  all_terms_url = find('div.soporte_year li a')['href'].match('.*listadoFichas.*').to_a.first.to_s

  #  it might seem a bit odd to do this only once we've worked out everything
  # else but doing it this way means we don't need to visit the all terms page
  # and then go back so it's one less network call per person
  id = get_unique_id(all_terms_url, term, iddiputado, name)

  # don't save things if we don't get an id
  if id.nil?
    # puts "no id so not saving"
    return
  end

  data[:id] = id

  # puts "%s - %s\n" % [ data[:name], data[:id] ]
  ScraperWiki.save_sqlite([:id, :term], data)
end

scrape_people('http://www.congreso.es/portal/page/portal/Congreso/Congreso/Diputados/DiputadosTodasLegislaturas')
scrape_memberships
