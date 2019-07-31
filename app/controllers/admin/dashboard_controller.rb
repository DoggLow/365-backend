module Admin
  class DashboardController < BaseController
    skip_load_and_authorize_resource

    def index
      @daemon_statuses = Global.daemon_statuses
      @currencies_summary = Currency.all.map(&:summary)
      @register_count = Member.count
      @nodes_status = Global.nodes_status
      @last_nodes_checked = Time.at(Global.last_nodes_checked || 0)
    end
  end
end
