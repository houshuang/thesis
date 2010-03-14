# TODO: These two lines are necessary. If these methods are not called
# before loading the classifier, they will fail when called later on.
# I really wish I knew why. Total mindfuck, aggravating bug.
# I FIGURE some class name is clobbering something else but it's not obvious
# what the hell is going on.

Entry.first.classifier_text
Stream.create(:entry_id => Entry.first, :user_id => 0)
Stream.last.category
Stream.last.destroy

require 'classifier'
class StreamUpdater
  def initialize(sleep_period)
    @sleep_for = sleep_period
    @last_update = (Time.now - sleep_period) # guarantee update on 1st run

    @classifiers = {}
    User.all.each do |u|
      c = Classifier::Bayes.new "liked", "disliked"

      u.liked.each { |e| 
        c.train_liked e.classifier_text 
      }

      u.disliked.each { |e| 
        c.train_disliked e.classifier_text 
      }
      
      # why the fuck user.email is not working is something I don't want
      # to solve right now.
      @classifiers[u.attributes["email"]] = c
    end

    self.update!
  end

  # TODO: Should re-rank entries when the number of classifications or users
  # changes.
  def update!
    if (@last_update + @sleep_for) <= Time.now then
      puts "StreamUpdater updating. It's currently: #{Time.now}" if DEBUG
      
      @last_update = Time.now
      
      Stream.refresh!
      load_class_predictions()
      log "Stream has been refreshed."
      return true
    else
      puts "StreamUpdater: no. It's currently: #{Time.now}" if DEBUG
      return false
    end
  end

  private
  def load_class_predictions
    User.all.each do |u|
      entries = Stream.unclassified(u)
      
      entries.each do |e|
        prediction = @classifiers[u.attributes["email"]].classify(e.classifier_text)
        Stream.prediction(e, prediction, u)
  
      end
    end
  end

end
