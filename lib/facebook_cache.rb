class FacebookCache < ActiveRecord::Base
  include FacebookHelper
  
  attr_accessor :oauth_token,:expires,:profile_id,:country,:locale
 
  def set_as_current_user(hash_obj)
    @oauth_token = hash_obj['oauth_token']
    @expires = hash_obj['expires']
    @profile_id = hash_obj['profile_id']
    @country = hash_obj['user']['country']
    @locale = hash_obj['user']['locale']
    
    all_friends
  end
  
  def get_badge(color='')
    style_color = 'style="color: '+color+' !important;"'
    return '<a href="http://www.facebook.com/profile.php?id='+facebook_id+'" target="_new_<%=user.facebook_id%>" title="Go to '+get_possessive_adj(self).downcase+' facebook"><span class="facebook_profile_link"></span></a> <a '+style_color+' href="/home?user_id='+facebook_id+'"  title="Go to '+get_possessive_adj(self).downcase+' home page">'+name+'</a>'
  end
  
  def profile_picture_url(type="square")
    return "http://graph.facebook.com/"+facebook_id+"/picture?type="+type
  end
  
  def all_friends
    
    return [] if !facebook_id
    
    friend = FacebookFriendCache.first(:conditions=>{:facebook_id=>facebook_id})
    
    if !friend
      friend = FacebookFriendCache.new(:facebook_id=>facebook_id,:updated_date=>Time.now)
      result_data = get_data("friends")

      if ActiveSupport::JSON.decode(result_data)["data"]
        friend.friends = result_data
        friend.save 
      end
    end
    
    if (Time.now - friend.updated_date) > 60*60*24
      friend.updated_date = Time.now
      result_data = get_data("friends")

      if ActiveSupport::JSON.decode(result_data)["data"]
        friend.friends = result_data
        friend.save 
      end
    end
    
    begin 
      result = ActiveSupport::JSON.decode(friend.friends)["data"]
      raise "no friend" if result == nil
      return result
    rescue
      return []
    end

  end
  
end