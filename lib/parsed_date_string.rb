# frozen_string_literal: true

class ParsedDateString
  def initialize(date_string:, date_regex: /(?<day>\d+) de (?<month>[^[:space:]]*) de (?<year>\d+)/)
    @date_string = date_string
    @date_regex = date_regex
  end

  def to_s
    return '' if match.nil?
    '%d-%02d-%02d' % [match[:year], month(match[:month]), match[:day]]
  end

  private

  attr_reader :date_string, :date_regex

  def match
    @match ||= date_string.match(date_regex)
  end

  def month(str)
    ['', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'].find_index(str.downcase) || raise("Unknown month #{str}".magenta)
  end
end
