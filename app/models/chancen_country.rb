# frozen_string_literal: true

class ChancenCountry
  ConfigError = Class.new(StandardError)

  class << self
    def all
      @all ||= begin
        payload = YAML.safe_load_file(Rails.root.join("config/chancen_countries.yml"))
        Array(payload.fetch("countries")).map { |attrs| new(**attrs.symbolize_keys) }
      rescue KeyError, Psych::SyntaxError => e
        raise ConfigError, "Invalid Chancen country configuration: #{e.message}"
      end
    end

    def live
      all.select(&:live?)
    end

    def codes
      all.map(&:code)
    end

    def live_codes
      live.map(&:code)
    end

    def find(code)
      return nil if code.blank?

      all.find { |country| country.code == code.to_s.upcase }
    end

    def valid_code?(code)
      find(code).present?
    end
  end

  attr_reader :code, :name, :team_name, :escalation_contact, :privacy_url, :terms_url, :isa_content_source

  def initialize(code:, name:, live:, team_name:, escalation_contact:, privacy_url:, terms_url:, isa_content_source:)
    @code = code.to_s.upcase
    @name = name
    @live = live
    @team_name = team_name
    @escalation_contact = escalation_contact
    @privacy_url = privacy_url
    @terms_url = terms_url
    @isa_content_source = isa_content_source
  end

  def live?
    @live == true
  end

  def as_json(*)
    {
      code: code,
      name: name,
      live: live?,
      team_name: team_name,
      escalation_contact: escalation_contact,
      privacy_url: privacy_url,
      terms_url: terms_url,
      isa_content_source: isa_content_source
    }
  end
end
