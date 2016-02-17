require 'rubygems'
require 'sonos'

def send_transport_message(name, player, part = '<Speed>1</Speed>')
  @transport_client ||= Savon.client endpoint: "http://194.74.214.194:#{Sonos::PORT}#{TRANSPORT_ENDPOINT}", namespace: Sonos::NAMESPACE, log: Sonos.logging_enabled
  action = "#{TRANSPORT_XMLNS}##{name}"
  message = %Q{<u:#{name} xmlns:u="#{TRANSPORT_XMLNS}"><InstanceID>0</InstanceID>#{part}</u:#{name}>}
  @transport_client.call(name, soap_action: action, message: message)
end

# Get information about the currently playing track.
# @return [Hash] information about the current track.
def get_now_playing(player)
  return nil if player == nil

  response = send_transport_message('GetPositionInfo', player)
  body = response.body[:get_position_info_response]
  doc = Nokogiri::XML(body[:track_meta_data])

  # No music
  return nil if doc.children.length == 0

  art_path = doc.xpath('//upnp:albumArtURI').inner_text

  # TODO: No idea why this is necessary. Maybe its a Nokogiri thing
  art_path.sub!('/getaa?s=1=x-sonos-http', '/getaa?s=1&u=x-sonos-http')

  {
    title: doc.xpath('//dc:title').inner_text,
    artist: doc.xpath('//dc:creator').inner_text,
    album: doc.xpath('//upnp:album').inner_text,
    info: doc.xpath('//r:streamContent').inner_text,
    queue_position: body[:track],
    track_duration: body[:track_duration],
    current_position: body[:rel_time],
    uri: body[:track_uri],
    album_art: "http://#{player.ip}:#{Sonos::PORT}#{art_path}"
  }
end

TRANSPORT_ENDPOINT = '/MediaRenderer/AVTransport/Control'
TRANSPORT_XMLNS = 'urn:schemas-upnp-org:service:AVTransport:1'
system = Sonos::System.new
player = nil
system.speakers.each do |speaker|
  if speaker.is_playing?
    player = speaker
    break
  end
end

SCHEDULER.every '10s' do
  metadata = get_now_playing(player)
  if metadata and player
    send_event("albumart", { image: metadata[:album_art] })
    send_event("nowplaying", { text: metadata[:artist] + ' - ' + metadata[:title], moreinfo: player.name })
  elsif player
    send_event("albumart", { image: 'assets/sonoslogo.png' })
    send_event("nowplaying", { text: "Nothing playing in " + player.name })
  else
    send_event("albumart", { image: 'assets/sonoslogo.png' })
    send_event("nowplaying", { text: "Unable to connect to any player" })
  end
end
