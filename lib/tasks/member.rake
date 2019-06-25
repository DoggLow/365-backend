namespace :member do
  desc "Calculate level of each members"
  task cal_level: :environment do
    Member.all.each do |member|
      member.calculate_level
    end
  end

end
