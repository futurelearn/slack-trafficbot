require 'aws-sdk-cloudwatch'
require 'slack-ruby-client'

def call(event: nil, context: nil)
  fail "Must set LOAD_BALANCER_NAME" if load_balancer_name.nil?
  fail "Must set SLACK_API_TOKEN" if slack_api_token.nil?

  send_slack_message
end

def slack_message_content
  res = number_of_requests

  <<~TEXT
    :traffic_light: Traffic Report at #{res[:timestamp]} :helicopter:
    Load balancer: #{load_balancer_name}
    Requests: #{res[:requests].floor} req/s
  TEXT
end

def client
  Aws::CloudWatch::Client.new
end

def number_of_requests
  # Returns a set of 5 minute data points in the last one hour
  resp = client.get_metric_data(
    metric_data_queries: [
      {
        id: "requestCount",
        metric_stat: {
          metric: {
            namespace: "AWS/ELB",
            metric_name: "RequestCount",
            dimensions: [
              {
                name: "LoadBalancerName",
                value: load_balancer_name,
              },
            ],
          },
          period: 300,
          stat: "Sum",
          unit: "Count",
        },
      },
    ],
    start_time: Time.now - 3600,
    end_time: Time.now,
  ).metric_data_results[0]

  { timestamp: resp.timestamps.first, requests: resp.values.first / 300 }
end

def send_slack_message
  slack = Slack::Web::Client.new(token: slack_api_token)

  slack.chat_postMessage(channel: slack_channel, text: slack_message_content, as_user: true)
end

def slack_api_token
  ENV['SLACK_API_TOKEN']
end

def slack_channel
  ENV['SLACK_CHANNEL'] || '#capacity'
end

def load_balancer_name
  ENV['LOAD_BALANCER_NAME']
end
