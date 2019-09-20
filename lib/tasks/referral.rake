namespace :referral do
  desc "Calculate pending referrals of Members"
  task calculate: :environment do
    Referral.pending.each { |referral| referral.calculate }
  end

  desc "Recalculate referrals of trades"
  task recalculate: :environment do
    Referral.where(modifiable_type: 'Trade').each do |referral|
      # puts "referral: #{referral.id}"
      account_versions = AccountVersion.where('modifiable_type = ? AND modifiable_id = ?', 'Referral', referral.id)
      next if account_versions.blank?
      account_versions.each do |account_version|
        puts "account_version: #{account_version.id}"
        # next if account_version.id < 5032
        account = Account.find_by(id: account_version.account_id)
        next if account.blank?
        puts "account: #{account.id}"
        balance = account.balance > account_version.balance ? account.balance - account_version.balance : 0
        account.update! balance: balance
      end
    end
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
