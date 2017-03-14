require 'scraped'

class MembershipRow < Scraped::HTML
  TERM_IDS_MAP = {
    'Legislatura' => '0',
    'I' => '1',
    'II' => '2',
    'III' => '3',
    'IV' => '4',
    'V' => '5',
    'VI' => '6',
    'VII' => '7',
    'VIII' => '8',
    'IX' => '9',
    'X' => '10',
    'XI' => '11',
    'XII' => '12'
  }.freeze

  field :term do
    TERM_IDS_MAP[noko.at_css('.principal').text.split.first]
  end

  field :constituency do
    constituency_and_faction_line.rpartition('(').first.tidy
  end

  field :faction do
    constituency_and_faction_line.rpartition('(').last.split(')').first.tidy
  end

  private

  def constituency_and_faction_line
    noko.css('.SUBTITULO_INTERMEDIO').text.split('por').last
  end
end
