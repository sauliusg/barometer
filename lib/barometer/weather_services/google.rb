module Barometer
  #
  # = Google Weather
  # www.google.com
  # NOTE: Google does not have an official API
  #
  # - key required: NO
  # - registration required: NO
  # - supported countries: ALL
  #
  # === performs geo coding
  # - city: YES (except postalcode query)
  # - coordinates: NO
  #
  # === time info
  # - sun rise/set: NO
  # - provides timezone: NO
  # - requires TZInfo: NO
  #
  # == resources
  # - API: http://unknown
  #
  # === Possible queries:
  # - http://google.com/ig/api?weather=perth
  #
  # where query can be:
  # - zipcode (US or Canadian)
  # - city state; city, state
  # - city
  # - state
  # - country
  #
  # = Google terms of use
  # This is an unoffical API.  There are no terms of use.
  #
  class WeatherService::Google < WeatherService
    
    #########################################################################
    # PRIVATE
    # If class methods could be private, the remaining methods would be.
    #
    
    def self._source_name; :google; end
    def self._accepted_formats; [:zipcode, :postalcode, :geocode]; end
    
    def self._wet_icon_codes
      %w(rain chance_of_rain chance_of_storm thunderstorm mist)
    end
    def self._sunny_icon_codes
      %w(sunny mostly_sunny partly_cloudy)
    end

    def self._build_current(data, metric=true)
      raise ArgumentError unless data.is_a?(Hash)
      current = Measurement::Result.new

      if data['current_conditions']
        data = data['current_conditions']
        if data['icon']
          icon_match = data['icon']['data'].match(/.*\/([A-Za-z_]*)\.png/)
          current.icon = icon_match[1] if icon_match
        end
        current.condition = data['condition']['data'] if data['condition']

        humidity_match = data['humidity']['data'].match(/[\d]+/)
        current.humidity = humidity_match[0].to_i if humidity_match
      
        current.temperature = Data::Temperature.new(metric)
        current.temperature << [data['temp_c']['data'], data['temp_f']['data']]
      
        current.wind = Data::Speed.new(metric)
        begin
          current.wind << data['wind_condition']['data'].match(/[\d]+/)[0]
          current.wind.direction = data['wind_condition']['data'].match(/Wind:.*?([\w]+).*?at/)[1]
        rescue
        end
      end
      current
    end
    
    def self._build_forecast(data, metric=true)
      raise ArgumentError unless data.is_a?(Hash)

      forecasts = Measurement::ResultArray.new
      return forecasts unless data && data['forecast_information'] &&
                              data['forecast_information']['forecast_date']
      start_date = Date.parse(data['forecast_information']['forecast_date']['data'])
      data = data['forecast_conditions'] if data['forecast_conditions']

      # go through each forecast and create an instance
      d = 0
      data.each do |forecast|
        forecast_measurement = Measurement::Result.new
        if forecast['icon']
          icon_match = forecast['icon']['data'].match(/.*\/([A-Za-z_]*)\.png/)
          forecast_measurement.icon = icon_match[1] if icon_match
        end
        forecast_measurement.condition = forecast['condition']['data'] if forecast['condition']

        if (start_date + d).strftime("%a").downcase == forecast['day_of_week']['data'].downcase
          forecast_measurement.date = start_date + d
        end

        forecast_measurement.high = Data::Temperature.new(metric)
        forecast_measurement.high << forecast['high']['data']
        forecast_measurement.low = Data::Temperature.new(metric)
        forecast_measurement.low << forecast['low']['data']
        
        forecasts << forecast_measurement
        d += 1
      end
      forecasts
    end
    
    def self._build_location(result=nil, geo=nil)
      raise ArgumentError unless (geo.nil? || geo.is_a?(Data::Geo))
      location = Data::Location.new
      if geo
        location.city = geo.locality
        location.state_code = geo.region
        location.country = geo.country
        location.country_code = geo.country_code
        location.latitude = geo.latitude
        location.longitude = geo.longitude
      end
      location
    end
    
    # use HTTParty to get the current weather
    def self._fetch(query, metric=true)
      return unless query
      puts "fetch google: #{query.q}" if Barometer::debug?
      self.get(
        "http://www.google.com/ig/api",
        :query => {:weather => query.q, :hl => (metric ? "en-GB" : "en-US")},
        :format => :xml,
        :timeout => Barometer.timeout
      )['xml_api_reply']['weather']
    end
    
  end
end