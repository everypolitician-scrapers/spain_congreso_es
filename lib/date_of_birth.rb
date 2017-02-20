# frozen_string_literal: true
class DateOfBirth
  DATE_REGEX = /(?<day>\d+) de (?<month>[^[:space:]]*) de (?<year>\d+)/

  def initialize(date_string)
    @date_string = date_string
  end

  def to_s
    return '' if match.nil?
    '%d-%02d-%02d' % [match[:year], month(match[:month]), match[:day]]
  end

  private

  attr_reader :date_string

  def match
    @match ||= date_string.match(DATE_REGEX)
  end

  def month(str)
    ['', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'].find_index(str.downcase) || raise("Unknown month #{str}".magenta)
  end
end
