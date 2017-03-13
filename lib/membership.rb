require 'field_serializer'
require 'pry'

class Membership
  include FieldSerializer

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

  def initialize(capybara_element)
    @capybara_element = capybara_element
  end

  field :term do
    term_ids(capybara_element.find('.principal').text)
  end

  field :constituency do
    capybara_element.find('.SUBTITULO_INTERMEDIO')
                    .text
                    .split('por')
                    .last
                    .split('(')
                    .first
                    .tidy
  end

  field :faction do
    if (line = capybara_element.find('.SUBTITULO_INTERMEDIO').text.match(/\((.+)\)/))
      return line[1].tidy.gsub('Grupo Parlamentario', 'G.P.')
    end
  end

  private

  attr_reader :capybara_element

  def term_ids(str)
    TERM_IDS_MAP[str.split.first]
  end
end
