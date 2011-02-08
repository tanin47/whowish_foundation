module ThumbnailismHelper
  
  def make_thumbnail(file_path,w,h)
    
    file_path = get_server_path_of(file_path)
    file_path = file_path[(RAILS_ROOT+'/public/').length..-1]
    
    new_file_name = file_path.gsub(/\//, '__')   
    
    thumbnail_path = RAILS_ROOT+'/public/uploads/thumbnail/'+w.to_s+'x'+h.to_s+'/'+new_file_name
    #print thumbnail_path + "\n"
    if !File.exists?(thumbnail_path)
      #print params[:file]+"\n"
      if !File.exists?(RAILS_ROOT + "/public/"+file_path)
        return ''
      end

      image_resize(RAILS_ROOT + "/public/"+file_path, w.to_i, h.to_i, thumbnail_path)
    end
    
    return '/uploads/thumbnail/'+w.to_s+'x'+h.to_s+'/'+new_file_name
    
  end
  
  def image_resize(src, w, h, dest)

    ensure_path(dest)
    
    # start resizing
    w = w.to_i
    h = h.to_i
    
    require 'mini_magick'
    image = MiniMagick::Image.from_file(src)
    ow,oh = image['%w %h'].split
    
    ow = ow.to_i
    oh = oh.to_i

    nw = w
    nh = h
    
    if (nw-ow).abs < (nh-oh).abs
      nh = (nw*oh/ow).to_i
    else
      nw = (ow*nh/oh).to_i
    end

    image.resize "#{w}x#{h}"
    
#    image.shave "0x#{(nh-h)}" if nh > h
#    image.shave "#{(nw-w)}x0" if nw > w
    
    image.write dest
  end
  
  def ensure_path(dest)
    #ensure directory structure
    dir = File.dirname(dest)
    print dir + "\n"
    
    token_dirs = dir.split('/')
    root_d = token_dirs[0]
    
    token_dirs[1..-1].each {|d|
      if !File.directory?(root_d+"/"+d)
        Dir.mkdir(root_d+"/"+d)
        File.chmod(0777, root_d+"/"+d)   
      end
      
      root_d = root_d+"/"+d
    }
  end
  
  # a temp file: temp_*
  # a item file: item_*
  #
  def get_server_path_of(full_file_path)

    full_file_path = full_file_path[1..-1] if full_file_path.match("^/")
    
    tokens = []
    
    if !full_file_path.match("^"+RAILS_ROOT+"/")
      
      tokens.push(Rails.root) 
      
      if !full_file_path.match("^public/")
        tokens.push('public') 
        
        if !full_file_path.match("^uploads/")
          tokens.push('uploads') 
        end
      end
    end
 
    full_file_path = tokens.join('/') +"/"+ full_file_path
    
    return full_file_path
  end
  
  def get_thumbnail_url(full_file_path, w, h)
    full_file_path = get_server_path_of(full_file_path)[(RAILS_ROOT+'/public/').length..-1]
    
    return "/thumbnail/"+w.to_s+"x"+h.to_s+"/"+ full_file_path
  end
  
  def delete_all_thumbnail_image(full_file_path)
    full_file_path = get_server_path_of full_file_path
    
    new_file_name = full_file_path.gsub(/\//, '__')
    
    Dir.foreach(RAILS_ROOT+"/public/uploads/thumbnail") do |entry|
 
      path = RAILS_ROOT+"/public/uploads/thumbnail/"+entry
      if File.directory?(path)
        if File.exists?(path+"/"+new_file_name)
          begin
            File.delete(path+"/"+new_file_name)
          rescue
          end
        end
      end
        
    end
  end
  
  def delete_image(full_file_path)
    
    full_file_path = get_server_path_of full_file_path
    
    delete_all_thumbnail_image(full_file_path)
    
    begin
      File.delete(full_file_path)
    rescue
    end

  end
  
end