#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "optparse"
require "uri"

class RemotePeopleImporter
  DEFAULT_COUNT = 500
  DEFAULT_PER_PAGE = 200
  DEFAULT_SOURCE = "openalex"

  def initialize(base_url:, count:, source:)
    @base_url = base_url
    @count = count
    @source = source
    @cookies = {}
  end

  def run!
    csrf_token, before_count = fetch_root!
    puts "Before import: #{before_count || 'unknown'} people"

    ids = fetch_external_ids
    puts "Fetched #{ids.length} #{@source} IDs"

    success = 0
    failures = []

    ids.each_with_index do |external_id, index|
      response, body = post_import(external_id, csrf_token)

      if response.code.to_i.between?(300, 399)
        success += 1
      elsif invalid_csrf?(response, body)
        csrf_token, = fetch_root!
        retry_response, retry_body = post_import(external_id, csrf_token)

        if retry_response.code.to_i.between?(300, 399)
          success += 1
        else
          failures << [ external_id, retry_response.code, retry_body.to_s[0, 160] ]
        end
      else
        failures << [ external_id, response.code, body.to_s[0, 160] ]
      end

      if ((index + 1) % 25).zero?
        puts "Progress: #{index + 1}/#{ids.length} processed, #{success} accepted, #{failures.length} failed"
      end

      sleep 0.05
    end

    _, after_count = fetch_root!
    puts "After import: #{after_count || 'unknown'} people"
    puts "Accepted imports: #{success} / #{ids.length}"

    return if failures.empty?

    puts "Failures:"
    failures.first(20).each do |external_id, code, snippet|
      puts "- #{external_id}: #{code} #{snippet.inspect}"
    end
  end

  private

  def fetch_root!
    response, body = request(:get, "#{@base_url}/")
    raise "root failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    csrf_token = body[/meta name="csrf-token" content="([^"]+)"/, 1]
    people_count = body[/<h2>(\d+) 人物<\/h2>/, 1]&.to_i
    raise "csrf token missing" if csrf_token.to_s.empty?

    [ csrf_token, people_count ]
  end

  def fetch_external_ids
    case @source
    when "openalex"
      fetch_openalex_ids
    else
      raise "unsupported source: #{@source}"
    end
  end

  def fetch_openalex_ids
    ids = []
    page = 1

    while ids.length < @count
      per_page = [ DEFAULT_PER_PAGE, @count - ids.length ].min
      uri = URI("https://api.openalex.org/authors")
      uri.query = URI.encode_www_form(
        sort: "cited_by_count:desc",
        "per-page": per_page,
        page: page,
        select: "id"
      )

      response, body = request(:get, uri.to_s, cookie_jar: false)
      raise "openalex page #{page} failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      page_ids = JSON.parse(body).fetch("results").map { |row| row.fetch("id").split("/").last }
      break if page_ids.empty?

      ids.concat(page_ids)
      ids.uniq!
      page += 1
    end

    ids.first(@count)
  end

  def post_import(external_id, csrf_token)
    request(
      :post,
      "#{@base_url}/person_imports",
      headers: { "X-CSRF-Token" => csrf_token },
      form: {
        "authenticity_token" => csrf_token,
        "source_name" => @source,
        "external_id" => external_id
      }
    )
  end

  def invalid_csrf?(response, body)
    response.code.to_i == 422 || body.to_s.include?("InvalidAuthenticityToken")
  end

  def request(method, url, headers: {}, form: nil, cookie_jar: true)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    request_class = method == :post ? Net::HTTP::Post : Net::HTTP::Get
    request = request_class.new(uri)
    request["User-Agent"] = "Codex/1.0"
    request["Accept"] = "text/html,application/json"
    request["Cookie"] = cookie_header unless @cookies.empty? || !cookie_jar
    headers.each { |key, value| request[key] = value }
    request.set_form_data(form) if form

    response = http.request(request)
    store_cookies!(response) if cookie_jar
    [ response, normalize_body(response.body) ]
  end

  def cookie_header
    @cookies.map { |key, value| "#{key}=#{value}" }.join("; ")
  end

  def store_cookies!(response)
    Array(response.get_fields("set-cookie")).each do |header|
      pair = header.split(";", 2).first
      key, value = pair.split("=", 2)
      @cookies[key] = value if key && value
    end
  end

  def normalize_body(body)
    body.to_s.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace)
  end
end

options = {
  base_url: "https://tsunagari.onrender.com",
  count: RemotePeopleImporter::DEFAULT_COUNT,
  source: RemotePeopleImporter::DEFAULT_SOURCE
}

OptionParser.new do |parser|
  parser.banner = "Usage: ruby script/import_remote_people.rb [options]"

  parser.on("--base-url URL", "Remote app base URL") do |value|
    options[:base_url] = value
  end

  parser.on("--count N", Integer, "How many people to import") do |value|
    options[:count] = value
  end

  parser.on("--source NAME", "External source (default: openalex)") do |value|
    options[:source] = value
  end
end.parse!

RemotePeopleImporter.new(**options).run!
