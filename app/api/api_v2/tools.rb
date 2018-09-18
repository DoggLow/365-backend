module APIv2
  class Tools < Grape::API
    desc 'Get server current time, in seconds since Unix epoch.'
    get "/timestamp" do
      { timestamp: Time.now.to_i }
    end
  end
end
