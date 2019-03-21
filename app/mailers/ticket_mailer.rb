class TicketMailer < BaseMailer

  def author_notification(ticket_id)
    ticket = Ticket.find ticket_id
    @ticket_url = "#{ENV['URL_SCHEMA']}://#{ENV['URL_UI']}/tickets/#{ticket_id}"

    mail to: ticket.author.email
  end

  def admin_notification(ticket_id)
    ticket = Ticket.find ticket_id
    @author_email = ticket.author.email
    @ticket_url = admin_ticket_url(ticket)

    mail to: ENV['SUPPORT_MAIL']
  end

end
