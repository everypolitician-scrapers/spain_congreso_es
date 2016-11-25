require 'fileutils'
require 'scraped_page_archive'

class GitArchive < ScrapedPageArchive::GitStorage
  def store(entry:)
    git.chdir { ArchiveWriter.new(entry: entry).write }
    git.add('.')
    git.commit(entry.commit_message)
    git.push('origin', branch_name)
  end
end

class ArchiveWriter
  def initialize(entry:)
    @entry = entry
  end

  def write
    body_file.dirname.mkdir unless body_file.dirname.exist?
    body_file.write(entry.body)
    metadata_file.dirname.mkdir unless metadata_file.dirname.exist?
    metadata_file.write(entry.metadata)
  end

  private

  attr_reader :entry

  def basename
    @basename ||= entry.key
  end

  def body_file
    @body_file ||= Pathname.new("#{basename}.html")
  end

  def metadata_file
    @metadata_file ||= Pathname.new("#{basename}.yml")
  end
end

class ArchiveEntry
  def initialize(response:)
    @response = response
  end

  def key
    @key ||= File.join(uri.host, Digest::SHA1.hexdigest(uri.to_s))
  end

  def body
    @body ||= response.body
  end

  def metadata
    @metadata ||= ResponseMetadata.new(response: response).to_yaml
  end

  def commit_message
    @commit_message ||= "#{response.status} #{response.url}"
  end

  private

  attr_reader :response

  def uri
    @uri ||= URI.parse(response.url.to_s)
  end
end

class ResponseMetadata
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
    entry = ArchiveEntry.new(response: response)
    ARCHIVE.store(entry: entry)
    super
  end
end
