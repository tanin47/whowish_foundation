module FacebookHelper
  
  def decode_signed_request

    $facebook = FacebookCache.get_guest
    
    begin
      if !params[:signed_request]
        params[:signed_request] = session[:signed_request]
      end

      session[:signed_request] = params[:signed_request]
      
      require "base64"
      
      tokens = params[:signed_request].split('.')
      sig = base64_urlsafe_decode(tokens[0])
      
      data = ActiveSupport::JSON.decode(base64_urlsafe_decode(tokens[1]))
      
      if data['algorithm'].to_s.upcase == 'HMAC-SHA256'
      
        require 'openssl'
        
        expected_sig = OpenSSL::HMAC.digest(OpenSSL::Digest::Digest.new('sha256'), APP_SECRET, tokens[1]).to_s
        $oauth_token = data['oauth_token']

        if sig == expected_sig and data['user_id']
          
          $facebook = get_facebook_info(data['user_id'])
          $facebook.set_as_current_user(data)
          
         
        end 
      end
      
      return data
    rescue
      $facebook = FacebookCache.get_guest
      return {}
    end
  end

  def generate_permission_url(scope,return_url)
      url = "http://www.facebook.com/dialog/oauth/?" 
      url += "scope="+scope.join(",")+"&" if scope.length > 0
      url += "client_id=" + APP_ID
      url += "&redirect_uri="+CGI.escape(return_url)
      return url
  end


  def get_facebook_info(id,force_update=false)
    
    return FacebookCache.get_guest if id == "0"
    
    profile = FacebookCache.first(:conditions=>{:facebook_id=>id})

    if !profile or force_update

      profile = FacebookCache.new(:facebook_id=>id,:updated_date=>Time.now) if !profile
      
      begin 
        data = ActiveSupport::JSON.decode get_data("",id)
        
        profile.name = data['name'] if data['name'] and data['name'] != ""
        profile.gender = data['gender']
        profile.email = data['email'] if data['email'] and data['email'] != ""
        
        profile.college = get_latest_college(data['education'])
      rescue
      end
    
      profile.updated_date = Time.now
      profile.save
    end
    
    if !force_update and (Time.now - profile.updated_date) > 60*60*24
      #schedule update job
      Delayed::Job.enqueue AsyncFacebookCache.new(id,$oauth_token)
    end
    
    return profile
  end
  
  def get_friends_of_friends(facebook_id)
    
    return [] if !facebook_id
    return [] if facebook_id == "0"
    
    friend = FacebookFriendCache.first(:conditions=>{:facebook_id=>facebook_id})
    
    return [] if !friend
    return friend.friends_of_friends.split(',')
  end
  
  def compute_friends_of_friends(friends)
    
    print friends.inspect 
    hash_f = {}
    friends.each { |friend_id| hash_f[friend_id] = true }
    
    fof = []
    FacebookFriendCache.all(:conditions=>["facebook_id in (?)",friends]).each { |ff|
      ff.friends.split(',').each { |fof_id|
        fof.push(fof_id) and (hash_f[fof_id] == true) if !hash_f[fof_id]
      }
    }
    print fof.inspect
    return friends + fof
  end
  
  def get_friends(facebook_id,force_update=false,get_remote=true)
    
    return [] if !facebook_id
    return [] if facebook_id == "0"
    
    friend = FacebookFriendCache.first(:conditions=>{:facebook_id=>facebook_id})
    
    if get_remote and (!friend or force_update)
      friend = FacebookFriendCache.new(:facebook_id=>facebook_id,:updated_date=>Time.now) if !friend
      result_data = get_data("friends",facebook_id)

      begin 
        data = ActiveSupport::JSON.decode(result_data)["data"]
        friend.friends = data.map{ |i| i["id"]}.join(',')
        friend.friends_of_friends  = compute_friends_of_friends(friend.friends.split(',')).join(',')
      rescue Exception=>e
        print "\n\n\n\n" + e + "\n\n\n\n"
      end
    
      friend.updated_date = Time.now
      friend.save 
    end
    
    return [] if !friend
    
    if !force_update and (Time.now - friend.updated_date) > 60*60*24
      #schedule update job
      Delayed::Job.enqueue AsyncFacebookFriendCache.new(facebook_id,$oauth_token)
    end

    return (friend.friends.split(',') rescue [])
  end
  
  private 
    def get_latest_college(json_data)
      return "" if !json_data
      return "" if json_data.length==0
      
      max_year = 0
      college_name = ""
      
      json_data.each { |block|
        if college_name == "" or \
            (block['year'] and block["year"]["name"].to_i > max_year) # some block does not have year
          max_year = block["year"]["name"].to_i if block["year"]
          college_name = block['school']['name']
        end
      }
      
      return college_name
    end
  
  private
    def get_data(method,user_id=facebook_id)

      require 'net/http'
      require 'net/https'
      require 'uri'
      
      Net::HTTP.version_1_2
      
      url = URI.parse("https://graph.facebook.com/"+user_id+"/"+method)
  
      http = Net::HTTP.new(url.host,url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      
      response = http.get(url.path+"?access_token="+$oauth_token)
      
       print "\n===== facebook_get_data =====\nURL:"+url.path+"\n" + response.body + "\n"
      return response.body
  end
  
  private
    def post_data(method,data,user_id=facebook_id)
     
      
      require 'cgi'
      nvp = "access_token="+$oauth_token  
      data.each_pair { |key, value| 
        nvp += '&' + key + '=' + CGI.escape(value)
      }
      
      print "\n"+nvp +"\n"

      require 'net/http'
      require 'net/https'
      require 'uri'
      
      Net::HTTP.version_1_2
      
      url = URI.parse("https://graph.facebook.com/"+user_id+"/"+method)
  
      http = Net::HTTP.new(url.host,url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      
      response = http.post(url.path,nvp)
      
      print "\n===== facebook_get_data =====\n" + response.body + "\n"
      return response.body
  end
  
  def get_possessive_adj(user,third_person_only=true)
    
    if !defined?(user.facebook_id)
      user = get_facebook_info(user)
    end
    
    if third_person_only == false and $facebook and user.facebook_id == $facebook.facebook_id 
      return "My"
    else
      return "Her" if user.gender == "female"
      return "His"
    end
  end
  
   def get_possessive_pronoun(user,third_person_only=true)
    
    if !defined?(user.facebook_id)
      user = get_facebook_info(user)
    end
    
    if third_person_only == false and $facebook and user.facebook_id == $facebook.facebook_id  
      return "Mine"
    else
      return "Hers" if user.gender == "female"
      return "His"
    end
  end
  
  def get_objective_pronoun(user)
    
    if !defined?(user.facebook_id)
      user = get_facebook_info(user)
    end
    
    if $facebook and user.facebook_id == $facebook.facebook_id
      return "me"
    else
      return "her" if user.gender == "female"
      return "him"
    end
  end
  
  def get_verb(subject, verb)
    
    index = (["I","you"].include?(subject))? 0:1;
    
    if ["have","has"].include? verb
      return ["have","has"][index]
    elsif ["want","wants"].include? verb
      return ["want","wants"][index]
    elsif ["can"].include? verb
      return "can"
    else
      raise "The verb '"+verb+"' is not supported"
    end
    
  end
  
  def get_pronoun(user,third_person_only=true)
    
    if !defined?(user.facebook_id)
      user = get_facebook_info(user)
    end
    
    return "I" if $facebook and user.facebook_id == $facebook.facebook_id
    
    return "she" if user.gender == "female"
    return "he"
    
  end
  
private 
  def base64_urlsafe_decode(str)
    
    encoded_str = str.gsub('-','+').gsub('_','/')
    encoded_str += '=' while !(encoded_str.size % 4).zero?
    return Base64.decode64(encoded_str)

  end
end
