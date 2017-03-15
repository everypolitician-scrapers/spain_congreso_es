require 'scraped'

class MembershipRow < Scraped::HTML

  TERM_IDS = ['Legislatura','I','II','III','IV','V','VI','VII','VIII','IX','X','XI','XII']

  field :term do
    a = TERM_IDS.index(noko.at_css('.principal').text.split.first)
    binding.pry
    a
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
