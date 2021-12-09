require 'sinatra'
require 'openapi_ruby_sdk' # replace with new gem name

include RubySdk # replace with new module name

BW_ACCOUNT_ID = ENV.fetch("BW_ACCOUNT_ID")
BW_USERNAME = ENV.fetch("BW_USERNAME")
BW_PASSWORD = ENV.fetch("BW_PASSWORD")
BW_MESSAGING_APPLICATION_ID = ENV.fetch("BW_MESSAGING_APPLICATION_ID")
BW_NUMBER = ENV.fetch("BW_NUMBER")
LOCAL_PORT = ENV.fetch("LOCAL_PORT")

set :port, LOCAL_PORT

RubySdk.configure do |config|
    # Configure HTTP basic authorization: httpBasic
    config.username = BW_USERNAME
    config.password = BW_PASSWORD
    #config.ssl_verify = false # remove for testing on push
end

$api_instance_msg = RubySdk::MessagesApi.new()

post '/sendMessage' do
    #Make a POST request to this URL to send a text message
    data = JSON.parse(request.body.read)
    body = MessageRequest.new
    body.application_id = BW_MESSAGING_APPLICATION_ID
    body.to = [data["to"]]
    body.from = BW_NUMBER
    body.text = data["text"]

    response = $api_instance_msg.create_message_with_http_info(BW_ACCOUNT_ID, body)

    return ''
end
