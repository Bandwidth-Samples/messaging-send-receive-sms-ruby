require 'sinatra'
require 'openapi_ruby_sdk_new' # replace with new gem name************

include RubySdk # replace with new module name**************

BW_ACCOUNT_ID = ENV.fetch("BW_ACCOUNT_ID")
BW_USERNAME = ENV.fetch("BW_USERNAME")
BW_PASSWORD = ENV.fetch("BW_PASSWORD")
BW_NUMBER = ENV.fetch("BW_NUMBER")
BW_MESSAGING_APPLICATION_ID = ENV.fetch("BW_MESSAGING_APPLICATION_ID")
LOCAL_PORT = ENV.fetch("LOCAL_PORT")

set :port, LOCAL_PORT

RubySdk.configure do |config|   # replace with new module name************   # Configure HTTP basic authorization: httpBasic
    config.username = BW_USERNAME
    config.password = BW_PASSWORD
end

$api_instance_msg = RubySdk::MessagesApi.new()  # replace with new module name************

post '/sendMessage' do  # Make a POST request to this URL to send a text message.
    data = JSON.parse(request.body.read)
    body = MessageRequest.new
    body.application_id = BW_MESSAGING_APPLICATION_ID
    body.to = [data["to"]]
    body.from = BW_NUMBER
    body.text = data["text"]

    response = $api_instance_msg.create_message(BW_ACCOUNT_ID, body)

    return ''
end

post '/callbacks/outbound/messaging/status' do  # This URL handles outbound message status callbacks.
    data = JSON.parse(request.body.read)
    case data[0]["type"] 
        when "message-sending"
            puts "message-sending type is only for MMS."
        when "message-delivered"
            puts "Your message has been handed off to the Bandwidth's MMSC network, but has not been confirmed at the downstream carrier."
        when "message-failed"
            puts "For MMS and Group Messages, you will only receive this callback if you have enabled delivery receipts on MMS."
        else
            puts "Message type does not match endpoint. This endpoint is used for message status callbacks only."
        end
    return ''
end

post '/callbacks/inbound/messaging' do  # This URL handles inbound message callbacks.
    data = JSON.parse(request.body.read)
    inbound_body = BandwidthCallbackMessage.new.build_from_hash(data[0])
    puts inbound_body.description
    if inbound_body.type == "message-received"
        puts "To: " + inbound_body.message.to[0] + "\nFrom: " + inbound_body.message.from + "\nText: " + inbound_body.message.text
    else
        puts "Message type does not match endpoint. This endpoint is used for inbound messages only.\nOutbound message status callbacks should be sent to /callbacks/outbound/messaging/status."
    end
    return ''
end
