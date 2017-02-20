# frozen_string_literal: true
class String
  def tidy
    gsub(/[[:space:]]+/, ' ').strip
  end
end
