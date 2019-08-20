namespace :solvency do

  desc "Generate new exchange addresses"
  task :new_addresses => :environment do
    begin
      puts "Generating coin addresses .."
      Currency.all.each do |currency|
        next if currency.fiat? || currency.erc20?

        result = currency.api.new_address!
        proof = Proof.create!(currency: currency.code)
        proof.update! result.extract!(:address, :secret).merge(details: result)
      end

      eth_proof = Proof.current :eth

      puts "Generating ERC20 addresses .."
      Currency.all.each do |currency|
        next unless currency.erc20?

        Proof.create!(currency: currency.code, address: eth_proof.address, secret: eth_proof.secret, details: eth_proof.details)
      end
    rescue => e
      puts e.inspect
    end
  end

  desc "Generate liability proof"
  task :liability_proof => :environment do
    Proof.all.each do |proof|
      begin
        next if proof.address.blank? || proof.currency_obj.nil?

        balance = proof.currency_obj.api.load_balance_of!(proof.address)
        proof.update! balance: balance
      rescue => e
        puts e.inspect
      end
    end

    puts "Complete."
  end

  desc "Sync balances of payment_addresses."
  task :sync_balance => :environment do
    Member.all.each do |member|
      next if member.deposits.blank?
      member.accounts.each do |account|
        begin
          next if account.payment_address.blank? || account.payment_address.address.blank? || account.currency_obj.nil? || !account.currency_obj.visible

          balance = account.currency_obj.api.load_balance_of!(account.payment_address.address)
          account.update! real_balance: balance
        rescue => e
          puts e.inspect
        end
      end
    end
    puts "Complete."
  end

end
