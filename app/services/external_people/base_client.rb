require "json"
require "net/http"
require "uri"

module ExternalPeople
  class BaseClient
    OPEN_TIMEOUT_SECONDS = 2
    READ_TIMEOUT_SECONDS = 3

    private

    def fetch_json(url, params: nil)
      uri = url.is_a?(URI) ? url.dup : URI(url)
      uri.query = URI.encode_www_form(params) if params.present?

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.open_timeout = OPEN_TIMEOUT_SECONDS
        http.read_timeout = READ_TIMEOUT_SECONDS
        request = Net::HTTP::Get.new(uri)
        request["Accept"] = "application/json"
        request["User-Agent"] = "Tsunagari/1.0"
        http.request(request)
      end

      raise ExternalPeople::Error, "外部データ取得に失敗しました: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue JSON::ParserError => error
      raise ExternalPeople::Error, "外部データの解析に失敗しました: #{error.message}"
    rescue StandardError => error
      raise if error.is_a?(ExternalPeople::Error)

      raise ExternalPeople::Error, "外部データ取得に失敗しました: #{error.message}"
    end

    def extract_localized_text(hash)
      return "" unless hash.is_a?(Hash)

      hash.dig("ja", "value").presence ||
        hash.dig("en", "value").presence ||
        hash.values.first&.dig("value").to_s
    end

    def extract_aliases(hash)
      return [] unless hash.is_a?(Hash)

      (hash["ja"] || hash["en"] || hash.values.first || []).filter_map { |entry| entry["value"].presence }.uniq
    end
  end
end
