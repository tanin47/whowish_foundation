module FacebookHelper
  
  def decode_signed_request
    #
    begin
    
      if !params[:signed_request]
        params[:signed_request] = session[:signed_request]
      end
      
      #print "sign request = " + params[:signed_request] + "\n"
      
      session[:signed_request] = params[:signed_request]
      
      require "base64"
      
      tokens = params[:signed_request].split('.')
      #print "token[0]="+tokens[0] + "--\n"
      #print "token[1]="+tokens[1] + "--\n"
      
      sig = base64_urlsafe_decode(tokens[0])
      
      #print "decode64(token[1])="+base64_urlsafe_decode(tokens[1]) + "--\n"
      
      data = ActiveSupport::JSON.decode(base64_urlsafe_decode(tokens[1]))
      
      if data['algorithm'].to_s.upcase != 'HMAC-SHA256'
        return
      end
      
      #require 'hmac-sha2'
      require 'openssl'
      
      expected_sig = OpenSSL::HMAC.digest(OpenSSL::Digest::Digest.new('sha256'), APP_SECRET, tokens[1]).to_s
      
#      print "sig="+sig +"--\n"
#      print "expected_sig="+expected_sig+"--\n"
      print ActiveSupport::JSON.encode(data)+"\n"
      print data['user_id'] +"\n"
      $oauth_token = data['oauth_token']
      
      print (sig == expected_sig).to_s + "\n\n"
  
      if sig == expected_sig and data['user_id']
        
        $facebook = get_facebook_info(data['user_id'])
        $facebook.set_as_current_user(data)
        #print ActiveSupport::JSON.encode($facebook)
      else
        $facebook = nil
      end
    rescue => e
      print e.to_s + "\n\n"
      logger.info 'in decode_signed_request #{e}'
      $facebook = nil
    end
    
    

  end

  

  
  def require_basic_information_permission(scope="")
    
    if !$facebook or $facebook.facebook_id == nil
      
      @redirect_url = "http://www.facebook.com/dialog/oauth/?" 
      @redirect_url += "scope="+scope+"&" if scope != ""
      @redirect_url += "client_id=" + APP_ID +
                   "&redirect_uri=http://apps.facebook.com/"+FACEBOOK_APP_NAME+"/"
      render "redirect/index", :layout=>"blank"
      return
    end
  end

  def get_facebook_info(id)
    profile = FacebookCache.first(:conditions=>{:facebook_id=>id})

    if !profile or (Time.now - profile.updated_date) > 60*60*24

      profile = FacebookCache.new(:facebook_id=>id,:updated_date=>Time.now) if !profile
      
      data = ActiveSupport::JSON.decode get_data("",id)
      
      profile.name = data['name'] if data['name'] and data['name'] != ""
      profile.gender = data['gender']
      profile.email = data['email'] if data['email'] and data['email'] != ""
      
      profile.college = get_latest_college(data['education'])
      profile.updated_date = Time.now
      profile.save
    end
    
    return profile
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
    def get_data(method,id="")
      print "START GET DATA"
      id = facebook_id if id == ""
      
      require 'net/http'
      require 'net/https'
      require 'uri'
      
      Net::HTTP.version_1_2
      
      url = URI.parse("https://graph.facebook.com/"+id+"/"+method)
  
      http = Net::HTTP.new(url.host,url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      
      response = http.get(url.path+"?access_token="+$oauth_token)
      
       print "\n===== facebook_get_data =====\nURL:"+url.path+"\n" + response.body + "\n"
      return response.body
  end
  
  private
    def post_data(method,data)
     
      
      require 'cgi'
      nvp = "access_token="+@oauth_token  
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
    
    if user.facebook_id == $facebook.facebook_id and third_person_only == false
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
    
    if user.facebook_id == $facebook.facebook_id and third_person_only == false
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
    
    if user.facebook_id == $facebook.facebook_id
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
    
    return "I" if user.facebook_id == $facebook.facebook_id
    
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
