#A simple sinatra server that handles interactions with Bandwidth's messaging API

require 'sinatra'
require 'bandwidth'

include Bandwidth
include Bandwidth::Messaging

BW_USERNAME = ENV.fetch("BW_USERNAME")
BW_PASSWORD = ENV.fetch("BW_PASSWORD")
BW_NUMBER = ENV.fetch("BW_NUMBER")
BW_MESSAGING_APPLICATION_ID = ENV.fetch("BW_MESSAGING_APPLICATION_ID")
BW_ACCOUNT_ID = ENV.fetch("BW_ACCOUNT_ID")
LOCAL_PORT = ENV.fetch("LOCAL_PORT")

set :port, LOCAL_PORT

bandwidth_client = Bandwidth::Client.new(
    messaging_basic_auth_user_name: BW_USERNAME,
    messaging_basic_auth_password: BW_PASSWORD
)
messaging_client = bandwidth_client.messaging_client.client

account_id = BW_ACCOUNT_ID

post '/callbacks/outbound/messaging' do
    #Make a POST request to this URL to send a text message
    data = JSON.parse(request.body.read)
    body = MessageRequest.new
    body.application_id = BW_MESSAGING_APPLICATION_ID
    body.to = [data["to"]]
    body.from = BW_NUMBER
    body.text = data["text"]

    messaging_client.create_message(account_id, body)

    return ''
end

post '/callbacks/outbound/messaging/status' do
    data = JSON.parse(request.body.read)
    case data[0]["type"] 
        when "message-sending"
            puts "message-sending type is only for MMS"
        when "message-delivered"
            puts "your message has been handed off to the Bandwidth's MMSC network, but has not been confirmed at the downstream carrier"
        when "message-failed"
            puts "For MMS and Group Messages, you will only receive this callback if you have enabled delivery receipts on MMS."
        else
            puts "Message type does not match endpoint. This endpoint is used for message status callbacks only."
        end
    return ''
end

post '/callbacks/inbound/messaging' do
    #This URL handles inbound messages.
    #If the inbound message contains media, that media is downloaded
    data = JSON.parse(request.body.read)
    if data[0]["type"] == "message-received"
        puts "Message received"
        puts "To: " + data[0]["message"]["to"][0] + "\nFrom: " + data[0]["message"]["from"] + "\nText: " + data[0]["message"]["text"]
    else
        puts "Message type does not match endpoint. This endpoint is used for inbound messages only.\nOutbound message callbacks should be sent to /callbacks/outbound/messaging."
    end
    return ''
end
