class TemporaryImageController < ActionController::Base
 include ThumbnailismHelper
 
 def index

    return_json = upload_temporary_image(params[:Filedata])

    response.headers['Content-type'] = 'text/plain; charset=utf-8'
    render :json=>return_json
  end
  
  def upload_temporary_image(image_data)
    temp_image = TemporaryImage.new
    temp_image.name = ""
    temp_image.created_date = Time.now
    
    if !temp_image.save
      return {:ok=>false, :error_message=>"The database has failed."}
    end
    
    begin
      
      ext = File.extname( image_data.original_filename ).sub( /^\./, "" ).downcase
      
      temp_image.name = "temp_"+temp_image.id.to_s+"."+ext
        
      if !["jpg","jpeg","gif","png"].include?(ext)
        return {:ok=>false, :error_message=>"The extension ("+ext+") is not allowed."}
      end
      
      input_file_stream = image_data.read
      
      if !temp_image.save
        return {:ok=>false, :error_message=>"The database has failed."}
      end
    
      File.open(RAILS_ROOT+"/public/uploads/"+temp_image.name, "wb") { |f| 
        f.write(input_file_stream) 
      }
      
      File.chmod(0777, get_server_path_of("/uploads/"+temp_image.name)) 

      #image_resize("public/uploads/temp/"+temp_image.name, 112, 112, "public/uploads/temp/"+thumbnailize_name(temp_image.name,112,112))
      
      return {:ok=>true, :filename=>"/uploads/"+temp_image.name}
    rescue Exception=>e
      
      if temp_image.name != ""
        begin
          delete_image(temp_image.name)
        rescue Exception=>ex
        end
      end
      
      return {:ok=>false, :error_message=>"The uploading has failed. Please try again. "+e}
    end
    

  end
  
end
