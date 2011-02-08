class ThumbnailController < ActionController::Base
  include ThumbnailismHelper
  
  def index
    
    if !(params[:size] =~ /[0-9]{1,4}x[0-9]{1,4}/)
      render :text=>"Invalid size"
      return
    end

    tokens = params[:size].split('x')
    w = tokens[0].to_i
    h = tokens[1].to_i
    
    url = make_thumbnail(params[:file],w,h)
    
    if url == '' or !File.exists?(RAILS_ROOT+'/public'+url)
      render :text=>"Not found"
    else
      redirect_to url
    end
  end
end
