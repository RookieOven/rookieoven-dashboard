#!/usr/bin/env ruby
require 'foursquare2'
require 'dotenv'
Dotenv.load

_api_client_id = ENV['FOURSQUARE_CLIENT_ID']
_api_client_secret = ENV['FOURSQUARE_CLIENT_SECRET']
_api_version = 20140225
_venue_id = '4e742eb48130fa6bd357880a'

SCHEDULER.every '5m', :first_in => 0 do |job|
  venue = Foursquare2::Client.new(:client_id => _api_client_id, :client_secret => _api_client_secret, :api_version => _api_version)
  venue_checkins = venue.herenow(_venue_id)
  send_event('foursquare_checkins_people', current: venue_checkins['hereNow']['count'])
end
