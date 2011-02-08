

## define schema
begin 
  ActiveRecord::Schema.define do
  
    create_table "whowish_words", :force => false do |t|
      t.string "page_name",      :null => false
      t.string "page_id",     :null => false
      t.string "word_id", :null => false
      t.text  "content", :null => false
      t.string  "locale", :null => false
    end
    
  end
rescue
  #do nothing
end

# extend Rails
require 'models/whowish_word'
require 'controllers/whowish_word_controller'

class ActionView::Base
  
  @@whowish_word = {}
  
  def self.init_whowish_word

    words = WhowishWord.all()
    
    words.each { |word|
      @@whowish_word[word.page_id] = {} if !@@whowish_word[word.page_id]
      
      @@whowish_word[word.page_id][word.word_id.to_sym] = word.content
    }
  end

  def word_for(id, *p)
    page_id = template.to_s
    
    if @@whowish_word[page_id] and @@whowish_word[page_id][id]
      
      s = @@whowish_word[page_id][id].to_s
      
     if p.length > 0
        p = p[0]

        p.each_pair { |key,val|
          s.gsub!("{"+key.to_s+"}",val.to_s)
        }
      end
      
      return s
    else
      raise page_id +" does not have any wordings" if !@@whowish_word[page_id]
      raise page_id +" does not contain wording for '"+id.to_s+"'" if !@@whowish_word[page_id][id]
    end
    
  end
end

# init all words
ActionView::Base.init_whowish_word

# load all controllers, helpers, and models
%w{ models controllers helpers }.each do |dir|
  path = File.join(File.dirname(__FILE__), 'app', dir)
  $LOAD_PATH.insert(0, path)
  ActiveSupport::Dependencies.load_paths.insert(0, path)
  ActiveSupport::Dependencies.load_once_paths.delete(path)
end

ActionController::Base.append_view_path(RAILS_ROOT+"/vendor/plugins/whowish_foundation/lib/app/views")

# add routes
class << ActionController::Routing::Routes;self;end.class_eval do
  define_method :clear!, lambda {}
end

ActionController::Routing::Routes.draw do |map|
  map.connect 'whowish_word/:action', :controller => 'whowish_word'
end