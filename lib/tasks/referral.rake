namespace :referral do
  desc "Calculate pending referrals of Members"
  task calculate: :environment do
    Referral.pending.each { |referral| referral.calculate }
  end

  desc "Calculate referral rewards of all members"
  task calculate_rewards: :environment do
    Member.all.each { |member| member.calculate_rewards }
  end

  desc "Generate referrer_ids column of members from referrer_id column"
  task gen_referrer_ids: :environment do
    Member.all.each { |member| member.set_referrer_ids }
  end

  desc "Compare time consumption for getting referrers"
  task compare_time_for_referrers: :environment do
    Member.all.each do |member|
      puts "=== Member: #{member.id} ==="

      start_time = Time.now
      referrer_ids = member.recur_referrers.map &:id
      puts "Referrers: #{referrer_ids}"
      delta = Time.now - start_time
      puts "Time in 'Adjacency List': #{delta} Seconds"

      start_time = Time.now
      referrer_ids = member.referrers.map &:id
      puts "Referrers: #{referrer_ids}"
      delta = Time.now - start_time
      puts "Time in 'Path Enumeration': #{delta} Seconds"
    end
  end

  desc "Compare time consumption for getting all referees"
  task compare_time_for_all_referees: :environment do
    Member.all.each do |member|
      puts "=== Member: #{member.id} ==="

      start_time = Time.now
      all_referee_ids = member.recur_all_referees.map &:id
      puts "All Referees: #{all_referee_ids}"
      delta = Time.now - start_time
      puts "Time in 'Adjacency List': #{delta} Seconds"

      start_time = Time.now
      all_referee_ids = member.all_referees.map &:id
      puts "All Referees: #{all_referee_ids}"
      delta = Time.now - start_time
      puts "Time in 'Path Enumeration': #{delta} Seconds"
    end
  end

end
