class WhowishWordController < ActionController::Base
  
  layout "whowish_word_blank"
  
  SHOW_FIELDS = [{:id=>"page_name",:width=>75},
          {:id=>"page_id",:width=>150},
          {:id=>"word_id",:width=>100},
          {:id=>"content",:type=>"textarea"}]

  def index
    @fs = SHOW_FIELDS
  end

  def restart
    system "touch "+RAILS_ROOT+"/tmp/restart.txt"
    render :json=>{:ok=>true}
  end
  
  def add
    
    entity = WhowishWord.new
    entity.page_name = params[:page_name].strip
    entity.page_id = params[:page_id].strip
    entity.word_id = params[:word_id].strip
    entity.content = params[:content].strip
    entity.locale = "en"
    
    if !entity.save
      render :json => {:ok=>false, :error_message=>format_error(entity.errors)}
      return
    end
    
    render :json=>{:ok=>true ,:new_row=>render_to_string(:partial=>"row",:locals=>{:entity=>entity,:field_set=>SHOW_FIELDS,:is_new=>false}), :entity=> entity}
    
  end
  
  def delete

    if !WhowishWord.delete(params[:id])
      render :json=>{:ok=>false,:error_message=>"error while delete location"}
      return
    end
 
    render :json=>{:ok=>true}
  end
  
 def edit
    entity = WhowishWord.first(:conditions=>{:id => params[:id]})
    entity.page_name = params[:page_name].strip
    entity.page_id = params[:page_id].strip
    entity.word_id = params[:word_id].strip
    entity.content = params[:content].strip
    
    if !entity.save
      render :json => {:ok=>false, :error_message=>format_error(entity.errors)}
      return
    end

  
    render :json=>{:ok=>true , :entity=> entity}
  end
end