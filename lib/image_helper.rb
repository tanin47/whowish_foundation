module ImageHelper
  include ThumbnailismHelper

  def update_picture(picture_list)
    last_image_id = EventImage.maximum(:id)
       if(last_image_id != nil)
        img_id = last_image_id + 1
      else
        img_id = 1
      end
      
      event_images = EventImage.all(:conditions=>{:event_id=>id},:order=>"ordered_number asc")
      event_images_name = event_images.map {|p| p.original_image_path}
     
      temp_images = picture_list.split(",")
      
      temp_images_name = []
      
      temp_images.each do |temp_image|
        temp_images_name.push(File.basename(temp_image))
      end

      event_images.each do |event_image|
        if !temp_images_name.include?(event_image.original_image_path)
          delete_image("/uploads/event/" + event_image.original_image_path)
          event_image.destroy
        end
      end
      
      event_images_after_del = EventImage.all(:conditions=>{:event_id=>id},:order=>"ordered_number asc")
      order = 0
      event_images_after_del.each do |image|
        image.ordered_number = order
        image.save
        order = order + 1
      end
      
      temp_images_name.each do |temp_image|
        if !event_images_name.include?(temp_image)
         
          ext = File.extname( temp_image ).sub( /^\./, "" ).downcase
          
          new_img_name = "event_" + id.to_s + "_" + img_id.to_s + "." + ext
          
          require 'ftools'
      
          begin
            File.copy(get_server_path_of("/uploads/temp/" + temp_image),get_server_path_of("/uploads/event/" + new_img_name))  
            File.chmod(0777, get_server_path_of("/uploads/event/" + new_img_name)) 
          rescue
          end
          
          eventImg = EventImage.new
          eventImg.event_id = id
          eventImg.ordered_number = order
          eventImg.original_image_path = new_img_name
          eventImg.save
          
          img_id = img_id + 1
          order = order + 1
          delete_image( "/uploads/temp/" + temp_image)

        end
      end
  end
  
end