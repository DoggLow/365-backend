module Admin
  class IdDocumentsController < BaseController
    load_and_authorize_resource

    def index
      @search_field = params[:search_field]
      case @search_field
      when 'verified'
        @id_documents = @id_documents.where(aasm_state: 'verified')
      when 'unverified'
        @id_documents = @id_documents.where.not(aasm_state: 'verified')
      else
      end
      @id_documents = @id_documents.order(:updated_at).reverse_order.page params[:page]
    end

    def show
    end

    def update
      @id_document.approve! if params[:approve]
      @id_document.reject!  if params[:reject]

      redirect_to admin_id_document_path(@id_document)
    end
  end
end
