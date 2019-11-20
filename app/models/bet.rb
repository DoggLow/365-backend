class Bet < ActiveRecord::Base

  COMPANY_PROFIT = 0.15
  BET_FEE = 0.05

  belongs_to :member

  validates_presence_of :credit, :member
  validates_numericality_of :credit, greater_than: 0

  validate :validate_data, on: :create

  def hold_account
    member.get_account(:btc)#btc
  end

  def validate_data
    if hold_account.blank?
      errors.add 'account', 'invalid'
    else
      balance = hold_account.balance
      if balance < credit
        errors.add 'balance', 'insufficient'
      end
    end
  end

  def make_payment()
    hold_account.sub_funds(self.credit, reason: Account::BET_SUB)
    CastingMailer.bet_accepted(self).deliver
  end

  def self.total_lose_credit(even_odd, sdate, edate)
    sql = "SELECT SUM(credit) as t_credit FROM bets WHERE even_odd <> %d AND created_at > '%s' AND created_at <= '%s';" % [even_odd, sdate, edate]
    records_array = ActiveRecord::Base.connection.execute(sql)
    if records_array.present?
      if records_array.first[0].blank?
        return 0
      end
      return records_array.first[0]
    else
      return 0
    end
  end

  def self.total_win_credit(even_odd, date)
    sql = "SELECT SUM(credit) as t_credit FROM bets WHERE even_odd = %d AND created_at > '%s' AND created_at <= '%s';" % [even_odd, sdate, edate]
    records_array = ActiveRecord::Base.connection.execute(sql)
    if records_array.present?
      if records_array.first[0].blank?
        return 0
      end
      return records_array.first[0]
    else
      return 0
    end
  end

  def self.make_judgement(even_odd, sdate, edate)
    t_lose_credit = total_lose_credit(even_odd, sdate, edate)
    t_win_credit = total_lose_credit(even_odd, sdate, edate)
    t_credit = t_lose_credit + t_win_credit

    if t_lose_credit == 0 && t_win_credit == 0
      return nil
    end

    t_share = (t_lose_credit - t_lose_credit * COMPANY_PROFIT)

    sql = 'UPDATE bets set '\
          'bonus = '\
            ' CASE '\
            ' WHEN even_odd = %d THEN (%f * credit / %f)'\
            ' ELSE 0 END, '\
          'fee = '\
            ' CASE '\
            ' WHEN even_odd = %d THEN (credit + %f * credit / %f) * %f'\
            ' ELSE 0 END, '\
          'result = '\
            ' CASE '\
            ' WHEN even_odd = %d THEN 1 '\
            ' ELSE 0 END'\
          ' WHERE created_at > "%s" AND created_at <= "%s"' % [even_odd, t_share, t_credit, even_odd, t_share, t_credit, BET_FEE, even_odd, sdate, edate]
    ActiveRecord::Base.connection.execute(sql)
  end

  def self.task_bet(even_odd, date)
    edate = DateTime.new(date.year, date.month, date.day, 1, 0, 0, date.zone)
    sdate = DateTime.new(date.year, date.month, date.day - 1, 1, 0, 0, date.zone)

    make_judgement(even_odd, sdate, edate)

    sql = "SELECT * FROM bets WHERE created_at > '%s' AND created_at <= '%s';" % [sdate, edate]
    records_array = ActiveRecord::Base.connection.exec_query(sql)

    if records_array.blank?
      return 0
    end

    records_array.each do |row|
      bet_item = find(row['id'])
      bet_item.update_account()
    end
    return result.count
  end

  def update_account()
    if result
      hold_account.plus_funds(credit - credit * BET_FEE, reason: Account::BET_RETURN)
      if bonus > 0
        hold_account.plus_funds(bonus - bonus * BET_FEE, reason: Account::BET_BONUS)
      end
      CastingMailer.bet_succeed(self).deliver
    else
      CastingMailer.bet_failed(self).deliver
    end
  end

end
