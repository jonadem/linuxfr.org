class WikiPagesController < ApplicationController
  before_filter :user_required, :except => [:index, :show, :show_diff]
  after_filter  :marked_as_read, :only => [:show]

  def index
    respond_to do |wants|
      wants.html { redirect_to WikiPage.find_by_title(WikiPage::HomePage) }
      wants.atom { @wiki_pages = WikiPage.sorted }
    end
  end

  def show
    begin
      @wiki_page = WikiPage.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      new
      @wiki_page.title = params[:id].titleize
      render :new and return
    end
    raise ActiveRecord::RecordNotFound unless @wiki_page && @wiki_page.readable_by?(current_user)
    redirect_to @wiki_page, :status => 301 if @wiki_page.has_better_id?
  end

  def new
    @preview_mode = false
    @wiki_page = WikiPage.new
  end

  def create
    @wiki_page = WikiPage.new
    @wiki_page.title = params[:wiki_page][:title]
    @wiki_page.user_id = current_user.id
    @wiki_page.attributes = params[:wiki_page]
    @preview_mode = (params[:commit] == 'Prévisualiser')
    if !@preview_mode && @wiki_page.save
      @wiki_page.create_node(:user_id => current_user.id)
      flash[:success] = "Nouvelle page de wiki créée"
      redirect_to @wiki_page
    else
      @wiki_page.node = Node.new
      render :new
    end
  end

  def edit
    @wiki_page = WikiPage.find(params[:id])
    @wiki_page.wiki_body = @wiki_body.versions.last.body
    raise ActiveRecord::RecordNotFound unless @wiki_page && @wiki_page.editable_by?(current_user)
  end

  def update
    @wiki_page = WikiPage.find(params[:id])
    raise ActiveRecord::RecordNotFound unless @wiki_page && @wiki_page.editable_by?(current_user)
    @wiki_page.attributes = params[:wiki_page]
    @wiki_page.committer  = current_user
    @preview_mode = (params[:commit] == 'Prévisualiser')
    if !@preview_mode && @wiki_page.save
      flash[:success] = "Modification enregistrée"
      redirect_to @wiki_page
    else
      render :edit
    end
  end

  def destroy
    @wiki_page = WikiPage.find(params[:id])
    raise ActiveRecord::RecordNotFound.new unless @wiki_page && @wiki_page.deletable_by?(current_user)
    @wiki_page.mark_as_deleted
    flash[:success] = "Page de wiki supprimée"
    redirect_to wiki_pages_url
  end

  def show_diff
    @wiki_page = WikiPage.find(params[:wiki_page_id])
    raise ActiveRecord::RecordNotFound unless @wiki_page && @wiki_page.readable_by?(current_user)
    @commit = Commit.new(@wiki_page, params[:sha])
  end

protected

  def marked_as_read
    current_user.read(@wiki_page.node) if current_user && @wiki_page.node
  end

end
