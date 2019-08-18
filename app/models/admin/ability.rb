module Admin
  class Ability
    include CanCan::Ability

    def initialize(user)
      return unless user.admin?

      can :read, Order
      can :read, Trade
      can :read, Proof
      can :read, Account
      can :read, PaymentAddress
      can :read, AssetTransaction
      can :manage, Document
      can :manage, Member
      can :manage, Setting
      can :manage, PurchaseOption
      can :manage, Product
      can :manage, Purchase
      can :manage, Ticket
      can :manage, IdDocument
      can :manage, TwoFactor

      can :menu, Deposit
      Currency.all.each { |c| can :manage, c }

      can :menu, Withdraw
      Currency.all.each { |c| can :manage, c }

    end
  end
end
