require 'fileutils'
require 'scraped_page_archive'

class GitArchive < ScrapedPageArchive::GitStorage
  def store(response:)
    uri = URI.parse(response.url.to_s)
    basename = File.join(uri.host, Digest::SHA1.hexdigest(uri.to_s))
    git.chdir do
      FileUtils.mkdir_p(File.dirname(basename))
      File.write("#{basename}.html", response.body)
      File.write("#{basename}.yml", ResponseSerializer.new(response: response).to_yaml)
    end
    git.add('.')
    message = "#{response.status} #{response.url}"
    git.commit(message)
    git.push('origin', branch_name)
  end
end

class ResponseSerializer
  def initialize(response:)
    @response = response
  end

  def to_yaml
    YAML.dump(to_h)
  end

  private

  attr_reader :response

  def to_h
    {
      'request' => {
        'method' => 'get',
        'uri' => response.url.to_s,
      },
      'response' => {
        'status' => {
          'code' => response.status.to_i,
        },
        'headers' => response.headers,
      }
    }
  end
end

class ArchiveDecorator < Scraped::Response::Decorator
  # Have a single instance of the archive so we don't keep re-cloning it.
  ARCHIVE = GitArchive.new

  def decorated_response
    # Archive the response
    ARCHIVE.store(response: response)
    super
  end
end
