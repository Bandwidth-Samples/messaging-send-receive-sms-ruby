require 'fileutils'
require 'sinatra'
require 'bandwidth-sdk'

begin
  BW_ACCOUNT_ID = ENV.fetch('BW_ACCOUNT_ID')
  BW_CLIENT_ID = ENV.fetch('BW_CLIENT_ID')
  BW_CLIENT_SECRET = ENV.fetch('BW_CLIENT_SECRET')
  BW_MESSAGING_APPLICATION_ID = ENV.fetch('BW_MESSAGING_APPLICATION_ID')
  BW_NUMBER = ENV.fetch('BW_NUMBER')
  LOCAL_PORT = Integer(ENV.fetch('LOCAL_PORT'))
rescue StandardError
  puts 'Please set the environmental variables defined in the README'
  exit(-1)
end

set :port, LOCAL_PORT
set :host_authorization, permitted_hosts: []

Bandwidth.configure do |config|
  config.client_id = BW_CLIENT_ID
  config.client_secret = BW_CLIENT_SECRET
  config.return_binary_data = true
end

STATUS_MESSAGES = {
  'message-sending' => 'message-sending type is only for MMS.',
  'message-delivered' => "Your message has been handed off to the Bandwidth's MMSC network, but has not been confirmed at the downstream carrier.",
  'message-failed' => 'For MMS and Group Messages, you will only receive this callback if you have enabled delivery receipts on MMS.'
}.freeze

def parse_body
  JSON.parse(request.body.read)
rescue JSON::ParserError
  halt 400
end

def parse_callbacks
  callbacks = parse_body
  halt 400 unless callbacks.is_a?(Array) && callbacks.all? { |callback| callback.is_a?(Hash) }
  callbacks
end

def save_media(media_url)
  media_id = media_url.partition('media/').last
  media_name = File.basename(media_id)
  return if media_name.end_with?('.xml')

  media = Bandwidth::MediaApi.new.get_media(BW_ACCOUNT_ID, media_id)
  FileUtils.mkdir_p('media')
  File.binwrite(File.join('media', media_name), media)
  puts "Saved media to media/#{media_name}"
rescue StandardError => e
  warn "Failed to download #{media_url}: #{e.message}"
end

post '/messages' do # Make a POST request to this URL to send a text message.
  data = parse_body
  halt 400 unless data.is_a?(Hash) && data['to'].is_a?(String) && data['text'].is_a?(String)

  media = data.fetch('media', [])
  halt 400 unless media.is_a?(Array) && media.all? { |url| url.is_a?(String) }

  message_request = Bandwidth::MessageRequest.new(
    application_id: BW_MESSAGING_APPLICATION_ID,
    to: [data['to']],
    from: BW_NUMBER,
    text: data['text'],
    media: media.empty? ? nil : media
  )

  begin
    message = Bandwidth::MessagesApi.new.create_message(BW_ACCOUNT_ID, message_request)
    puts "Sent message #{message.id}"
  rescue StandardError => e
    warn "Failed to send message: #{e.message}"
    halt 500
  end

  status 204
end

post '/callbacks/outbound/messaging/status' do # This URL handles outbound message status callbacks.
  callbacks = parse_callbacks
  halt 400 unless callbacks.all? { |callback| STATUS_MESSAGES.key?(callback['type']) }

  callbacks.each { |callback| puts STATUS_MESSAGES[callback['type']] }
  status 204
end

post '/callbacks/inbound/messaging' do # This URL handles inbound message callbacks.
  callbacks = parse_callbacks
  halt 400 unless callbacks.all? { |callback| callback['type'] == 'message-received' }

  callbacks.each do |callback|
    message = callback['message']
    puts "#{callback['description']}\nTo: #{message['to'][0]}\nFrom: #{message['from']}\nText: #{message['text']}"
    message.fetch('media', []).each { |media_url| save_media(media_url) }
  end
  status 204
end
