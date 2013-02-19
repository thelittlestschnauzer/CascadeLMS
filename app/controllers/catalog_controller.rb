class CatalogController < ApplicationController

  before_filter :ensure_logged_in, :set_tab

  def index
    @programs = Program.find(:all, :order => 'title asc')
    @courses = Hash.new
    
    # It only makes sens 
    @programs.each do |program|
      @courses[program.id] = program.courses_in_term(@term)
    end

    @other_courses = Course.courses_in_term_without_a_program(@term)

    @half_size = @programs.size / 2
    @oc_half_size = @other_courses.size / 2
  end

  def course
    @course = Course.find(params[:id])
  end

  private
  def set_tab
    @tab = 'catalog'
    @title = 'Course Catalog'
    @breadcrumb = Breadcrumb.new
    @breadcrumb.catalog = true
  end
end