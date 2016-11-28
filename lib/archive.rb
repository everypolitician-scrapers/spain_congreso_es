require 'English'
require 'fileutils'
require 'scraped_page_archive'

class GitArchive
  def initialize(git_url: git_remote_get_url_origin, branch: 'scraped-pages-archive')
    @git_url = git_url
    @branch = branch
  end

  def store(entry:)
    git.chdir do
      entry.files.each do |path, content|
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, content)
      end
    end
    git.add('.')
    git.commit(entry.commit_message)
    git.push('origin', branch)
  end

  private

  attr_reader :git_url, :branch

  def tmpdir
    @tmpdir ||= Dir.mktmpdir
  end

  def git
    @git ||= Git.clone(git_url, tmpdir).tap do |g|
      g.config('user.name', "scraped_page_archive gem #{ScrapedPageArchive::VERSION}")
      g.config('user.email', "scraped_page_archive-#{ScrapedPageArchive::VERSION}@scrapers.everypolitician.org")
      if g.branches[branch] || g.branches["origin/#{branch}"]
        g.checkout(branch)
      else
        g.chdir do
          # FIXME: It's not currently possible to create an orphan branch with ruby-git
          # @see https://github.com/schacon/ruby-git/pull/140
          system("git checkout --orphan #{branch}")
          system('git rm --quiet -rf .')
        end
        g.commit('Initial commit', allow_empty: true)
      end
    end
  end

  def git_remote_get_url_origin
    remote_url = `git config remote.origin.url`.chomp
    return nil unless $CHILD_STATUS.success?
    remote_url
  end
end

class ArchivePath
  def initialize(uri)
    @uri = URI.parse(uri.to_s)
  end

  def to_s
    File.join(uri.host, Digest::SHA1.hexdigest(uri.to_s))
  end

  private

  attr_reader :uri
end

# Gets a response back out of the archive.
class ArchiveStrategy < Scraped::Request::Strategy
  def response
    Scraped::Response.new(body: body, status: status, headers: headers, url: url)
  end

  private

  def status
    @status ||= metadata['response']['status']['code'].to_i
  end

  def headers
    metadata['response']['headers'].to_h
  end

  def body
    @body ||= File.read("#{key}.html")
  end

  def metadata
    @metadata ||= YAML.load_file("#{key}.yml")
  end

  def key
    @key ||= ArchivePath.new(url)
  end
end

class ArchiveEntry
  def initialize(response:)
    @response = response
  end

  def files
    {
      "#{key}.html" => response.body,
      "#{key}.yml" => ResponseMetadata.new(response: response).to_yaml,
    }
  end

  def commit_message
    @commit_message ||= "#{response.status} #{response.url}"
  end

  private

  attr_reader :response

  def key
    @key ||= ArchivePath.new(response.url)
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
    ARCHIVE.store(entry: ArchiveEntry.new(response: response))
    super
  end
end
