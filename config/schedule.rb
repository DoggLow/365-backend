# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

env :PATH, ENV['PATH']
env :GEM_PATH, ENV['GEM_PATH']

every '0 0 15 * *' do
  rake 'referral:calculate'
end

every 1.day, :at => '0:30 am' do
  rake 'referral:calculate_rewards'
end

every 1.day, :at => '0:00 am' do
  rake 'member:cal_level'
end

every '0 2 1 * *' do
  rake 'coin:pay_profit_invests'
end

every 1.day, :at => '0:00 am' do
  rake 'coin:pay_profit_cc_purchase'
end

every 5.minutes do
  rake 'solvency:liability_proof'
end

every 1.day, :at => '4:00 pm' do
  rake 'solvency:sync_balance'
end

every 1.day, :at => '3:00 pm' do
  rake 'coin:claim_neo_gas'
end
