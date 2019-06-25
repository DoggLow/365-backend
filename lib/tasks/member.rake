namespace :member do
  desc "Check and update state of affiliations"
  task affiliate: :environment do
    Affiliation.wait.each do |affiliation|
      affiliation.check
    end
  end

  desc "Calculate level of each members"
  task cal_level: :environment do
    Member.all.each do |member|
      member.calculate_level
    end
  end

end
