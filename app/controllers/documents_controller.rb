# Public club documents (rules and regulations): no sign-in and no role needed.
class DocumentsController < ApplicationController
  def index
    @documents = Document.published.ordered
  end

  def show
    @document = viewable_documents.find_by!(slug: params[:slug])
  end

  private

  # Admins open drafts to check them before publishing; everyone else sees published documents only.
  def viewable_documents
    return Document.all if user_signed_in? && current_user.admin?

    Document.published
  end
end
