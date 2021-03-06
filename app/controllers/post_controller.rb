class PostController < ApplicationController

  before_filter :ensure_logged_in

  def index
    redirect_to :controller => '/home', :course => nil, :action => nil, :id => nil
  end

  def view
    @item = Item.find(params[:id])
    return unless allowed_to_view_item(@user, @item)

    if @item.mark_notifications_read_for_user(@user)
      @notificationCount = @user.notification_count
    end

    if @item.blog_post?
      return redirect_to :controller => '/blog', :action => 'post', :course => @item.course_id, :id => @item.post_id
    elsif @item.forum?
      return redirect_to :controller => '/forums', :action => 'read', :course => @item.course_id, :id => @item.forum_post_id
    end

    return unless comments_open(@item)

    # Default breadcrumb
    @breadcrumb = Breadcrumb.new()
    @breadcrumb.text = 'View Post'
    @title = @item.title

    # Customize the menu display, depending on the kind of item.
    # Attempt to make the menus as integrated as possible w/ normal course flow.
    if !@item.course.nil? && allowed_to_see_course(@item.course, @user, false)
      @course = @item.course
      @show_course_tabs = true
      if @item.assignment? || @item.graded_assignment?
        @tab = 'course_assignments'
        @breadcrumb = Breadcrumb.for_course(@course)
        @breadcrumb.assignment = @item.assignment
        @breadcrumb.text = 'Comments'
        @breadcrumb.link = url_for(:action => 'view', :id => @item)
      elsif @item.document?
        @tab = 'course_documents'
      elsif @item.wiki?
        @tab = 'course_wiki'
      end
    end

    respond_to do |format|
      format.html {
        # For new comments
        @item_comment = ItemComment.new
      }
      format.xml {
        render :layout => false 
      }
    end
  end

  def comment
    @item = Item.find(params[:id])
    return unless allowed_to_view_item(@user, @item)

    @item_comment = ItemComment.new(params[:item_comment])
    @item_comment.user = session[:user]
    @item_comment.ip = session[:ip]
    @item = Item.add_comment(@item, @item_comment)

    link = url_for(:action => 'view', :id => @item, :only_path => false)
    Bj.submit "./script/runner ./jobs/comment_notify.rb #{@item.id} #{@user.id} \"#{link}\""

    redirect_to :action => 'view', :id => params[:id]
  end

  def aplus
    @item = Item.find(params[:item])
    return unless allowed_to_view_item(@user, @item)
    @item, userApRec = Item.toggle_plus(@item, @user)

    link = url_for(:action => 'view', :id => @item, :only_path => false)
    Bj.submit "./script/runner ./jobs/aplus_notify.rb #{@item.id} #{@user.id} \"#{link}\""

    render :layout => false
  end

  private
  def comments_open(item)
    unless item.enable_comments?
      flash[:notice] = "Comments have been disabled."
      redirect_to :controller => '/post', :action => 'view', :id => item.id, :class => nil, :assignment => nil
      return false
    end
    true
  end
end
