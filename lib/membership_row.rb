require 'scraped'

class MembershipRow < Scraped::HTML
  TERM_IDS = ['Legislatura','I','II','III','IV','V','VI','VII','VIII','IX','X','XI','XII']

  field :term do
    TERM_IDS.index(noko.at_css('.principal').text.split.first)
  end

  field :constituency do
    # Anything after the first '(' is considered to be the faction name
    # Example where constituency precedes faction:
    #   "Guipuzcoa ( Grupo Parlamentario Mixto )"
    # Example where contstituency is listed without faction:
    #   "Navarra"
    constituency_and_faction_line.rpartition('(').reject(&:empty?).first
  end

  field :faction do
    # The faction is assumed to be the substring within parentheses
    # Eg: Guipúzcoa ( Grupo Parlamentario Mixto )
    constituency_and_faction_line.match(/\(([^)]+)\)/){1}
  end

  private

  def constituency_and_faction_line
    place_article_at_start(noko.css('.SUBTITULO_INTERMEDIO').text.split('por').last)
  end

  def place_article_at_start(str)
    # Sometimes a constituency is displayed with the definited article in brackets:
    # This function moves the article out of brackets and places it at the start
    # "area (article) (faction)" becomes "article area (faction)"
    article = str[/\(Los\)|\(Las\)|\(El\)|\(La\)/] or return str
    "#{article.gsub(/\(|\)/,'')} #{str.gsub(article,'')}" rescue binding.pry
  end
end
