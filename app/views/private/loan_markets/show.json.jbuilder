json.offers @offers
json.demands @demands
json.active_loans @active_loans

if @member
  json.my_active_loans @loans_active.map(&:for_notify)
  json.my_open_loan_offers *([@loan_offers_wait] + OpenLoan::ATTRIBUTES)
end
