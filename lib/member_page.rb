require 'scraped_page'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

class MemberPage < ScrapedPage
  # Remove session information from url
  def url
    super.to_s.match(/(.*)_piref[\d_]+\.(next_page.*)/).captures.join('')
  end

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
    name.split(/,/).first.tidy
  end

  field :given_names do
    name.split(/,/).last.tidy
  end

  field :gender do
    return 'female' if seat.include? 'Diputada'
    return 'male' if seat.include? 'Diputado'
  end

  field :source do
    url.to_s
  end

  field :dob do
    # TODO: Make a class to encapsulate parsing the DOB.
  end

  field :faction do
    faction_information[:faction].tidy
  end

  field :faction_id do
    faction_information[:faction_id].tidy
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
    @faction_information ||= group.match(/(?<faction>.*?) \((?<faction_id>.*?)\)/)
  end
end
