require 'net/http'

class ScraperController < ApplicationController
  def home
  end

  def login
    scraper = CCScraper.new
    cookies = scraper.login(params[:username], params[:password])
    if cookies[0].is_a?(String)
      flash[:error] = cookies[0]
      redirect_to scraper_path and return
    end

    user = User.find_by_id(session[:user_id])
    # TODO(nharper): The delete_all line might not necessary
    user.scraper_credentials.delete_all
    user.scraper_credentials = cookies

    redirect_to scraper_path
  end

  def update_rehearsals
    time_zone = ActiveSupport::TimeZone['Pacific Time (US & Canada)']
    user = User.find_by_id(session[:user_id])
    scraper = CCScraper.new(user.scraper_credentials)
    concerts = scraper.scrape_api('/api/choruses/sfgmc/concerts')

    if concerts.is_a?(Hash) and concerts['error'] != nil
      flash[:error] = concerts['error']
      redirect_to scraper_path and return
    end

    begin
      concerts.each do |concert|
        next unless concert['is_active']
        c = Concert.find_or_initialize_by(:foreign_key => concert['id'])
        c.name = concert['name']
        c.is_active = concert['is_active']
        c.save

        concert['events'].each do |event|
          next unless event['track_attendance']
          rehearsal = Rehearsal.find_or_initialize_by(:foreign_key => event['id'])
          rehearsal.concert = c
          rehearsal.attendance = event['attendance_points'] > 0 ? :required : :optional
          rehearsal.weight = [event['attendance_points'], 1].max
          rehearsal.start_grace_period = 45.minutes
          rehearsal.start_date = time_zone.local_to_utc(Time.at(event['start_time_ms']/1000).utc)
          rehearsal_end_date = time_zone.local_to_utc(Time.at(event['end_time_ms']/1000).utc)
          if event['name'] != 'Rehearsal'
            rehearsal.name = event['name']
          end
          rehearsal.save
        end
      end
    rescue Exception => e
      flash[:error] = e
    end

    redirect_to scraper_path
  end

  private
end

class CCScraper
  def initialize(cookies = nil)
    @http_conn = Net::HTTP.new('app.chorusconnection.com', 443)
    @http_conn.use_ssl = true

    @headers = {}
    @cookies = []
    if cookies
      @cookies = cookies
      update_cookie_header
    end
  end

  def login(username, password)
    homepage_resp = @http_conn.get('/sign_in')
    update_cookies(homepage_resp.get_fields('Set-Cookie'))

    post_headers = @headers.clone
    post_headers['Content-Type'] = 'application/json;charset=UTF-8'
    auth_api_resp = @http_conn.post('/api/auth', {:email => username, :password => password}.to_json, post_headers)
    update_cookies(auth_api_resp.get_fields('Set-Cookie'))
    body = JSON.parse(auth_api_resp.body)
    if body['errors']
      return body['errors'].to_a
    end
    auth_token = ScraperCredential.new(:cookie_name => 'auth_token', :cookie_value => body['auth_token'])
    @cookies << auth_token
    update_cookie_header
    return @cookies
  end

  def scrape_api(api_path)
    return JSON.parse(@http_conn.get(api_path, @headers).body)
  end

  private

  def update_cookies(cookies)
    cookies.each do |cookie|
      cookie = cookie.split(';')[0]
      name, value = cookie.split('=')
      c = ScraperCredential.new(:cookie_name => name, :cookie_value => value)
      @cookies << c
    end
    update_cookie_header
  end

  def update_cookie_header
    @headers['Cookie'] = @cookies.map {|c| "#{c.cookie_name}=#{c.cookie_value}" }.join('; ')
  end
end
