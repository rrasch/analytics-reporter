require 'yaml'
require 'json'
require 'mechanize'

module RSBE
  class Config
    attr_reader :base_url, :user, :password, :auth_type, :login_path

    def initialize(path)
      data = YAML.load_file(path)
      rsbe = data.fetch('rsbe')

      @base_url   = rsbe.fetch('BaseURL')
      @user       = rsbe.fetch('User')
      @password   = rsbe.fetch('Password')
      @auth_type  = rsbe.fetch('AuthType')
      @login_path = rsbe.fetch('LoginPath')
    end
  end

  class APIClient
    def initialize(conf)
      @conf = conf
      @agent = Mechanize.new
    end

    def login
      raise 'LoginPath is required for cookie authentication' if @conf.login_path.empty?

      url = "#{@conf.base_url}#{@conf.login_path}"

      response = @agent.post(
        url,
        JSON.generate(
          email: @conf.user,
          password: @conf.password
        ),
        {
          'Content-Type' => 'application/json'
        }
      )

      check_response(response, 'login failed')

      true
    rescue Mechanize::ResponseCodeError => e
      raise build_error(e, 'login failed')
    end

    def get(path_or_url)
      url =
        if path_or_url.start_with?('http://', 'https://')
          path_or_url
        else
          "#{@conf.base_url}#{path_or_url}"
      end

      begin
        response = @agent.get(url)
      rescue Mechanize::ResponseCodeError => e
        raise build_error(e, 'bad response')
      end

      check_response(response, 'bad response')

      response
    end

    def get_body(path_or_url)
      get(path_or_url).body
    end

    private

    def check_response(response, prefix)
      code = response.code.to_i

      return if [200, 201].include?(code)

      error_text =
        begin
          JSON.parse(response.body)['error']
        rescue
          response.body
        end

      raise "#{prefix}: #{code} ; #{error_text}"
    end

    def build_error(exception, prefix)
      body =
        begin
          exception.page&.body
        rescue
          nil
        end

      error_text =
        begin
          JSON.parse(body)['error']
        rescue
          body || exception.message
        end

      "#{prefix}: #{exception.response_code} ; #{error_text}"
    end
  end
end
