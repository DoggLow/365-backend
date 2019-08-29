namespace :benchmark do

  def random_string(length)
    charset = Array('A'..'Z') + Array('a'..'z') + Array('0'..'9')
    Array.new(length) { charset.sample }.join
  end

  desc "Test Redis"
  task :cache_redis => %w(environment) do
    # Generate data.(approximate 50000)
    length = 50
    data = []
    # data = {}
    count = 1000000
    (1..count).each { |i|
      # data[random_string(length)] = 1
      data << random_string(length)
    }
    data.uniq

    puts "Data length: #{data.length}"

    puts "Write benchmark."

    start_time = Time.now
    Rails.cache.write "benchmark:test", data
    delta = Time.now - start_time
    puts "Time in 'writing data in one key': #{delta} Seconds"

    start_time = Time.now
    data.each { |item|
      Rails.cache.write "benchmark:#{item}", '1'
    }
    delta = Time.now - start_time
    puts "Time in 'writing an item per one key': #{delta} Seconds"

    puts "Querying benchmark."

    search_key = random_string(length)

    start_time = Time.now
    cached_data = Rails.cache.read "benchmark:test"
    query_result = cached_data.include?(search_key) # array querying
    # query_result = cached_data.key?(search_key) # hash querying
    delta = Time.now - start_time
    puts "Search result: #{query_result}"
    puts "Time in 'querying a record in data in one key': #{delta} Seconds"

    start_time = Time.now
    cached_data = Rails.cache.read "benchmark:#{search_key}"
    query_result = cached_data.present?
    delta = Time.now - start_time
    puts "Search result: #{query_result}"
    puts "Time in 'querying a record in all keys': #{delta} Seconds"

    puts "Clearing testing data."
    Rails.cache.delete_matched "benchmark:*"

    puts "Benchmark ended."
  end

  desc "In memory matching engine benchmark"
  task :matching => %w(environment) do
    num   = ENV['NUM'] ? ENV['NUM'].to_i : 250
    round = ENV['ROUND'] ? ENV['ROUND'].to_i : 4
    label = ENV['LABEL'] || Time.now.to_i

    puts "\n>> Setup environment (num=#{num} round=#{round})"
    Dir[Rails.root.join('tmp', 'matching_result_*')].each {|f| FileUtils.rm(f) }

    Benchmark::Matching.new(label, num, round).run
  end

  desc "Trade execution benchmark"
  task :execution => %w(environment) do
    executor = ENV['EXECUTOR'] ? ENV['EXECUTOR'].to_i : 8
    num   = ENV['NUM'] ? ENV['NUM'].to_i : 250
    round = ENV['ROUND'] ? ENV['ROUND'].to_i : 4
    label = ENV['LABEL'] || Time.now.to_i

    puts "\n>> Setup environment (executor=#{executor} num=#{num} round=#{round})"
    Dir[Rails.root.join('tmp', 'matching_result_*')].each {|f| FileUtils.rm(f) }
    Dir[Rails.root.join('tmp', 'concurrent_executor_*')].each {|f| FileUtils.rm(f) }

    Benchmark::Execution.new(label, num, round, executor).run
  end

  desc "Run integration benchmark"
  task :integration => %w(environment) do
    num = ENV['NUM'] ? ENV['NUM'].to_i : 400
    puts "Integration Benchmark (num: #{num})\n"

    Benchmark::Integration.new(num).run
  end

end
