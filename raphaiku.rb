require 'marky_markov'
require 'ruby_rhymes'
require 'twitter'
require 'rapgenius'
require_relative './rappers'


def configure_twitter_client
  client = Twitter::REST::Client.new do |config|
    config.consumer_key = ENV["TWITTER_KEY"]
    config.consumer_secret = ENV["TWITTER_SECRET"]
    config.access_token = ENV["ACCESS_TOKEN"]
    config.access_token_secret = ENV["ACCESS_SECRET"]
  end
  client
end


class HaikuCreator
  attr_reader :haiku

  def initialize(artist)
    @dict = MarkyMarkov::TemporaryDictionary.new
    @artist = artist
    get_songs
    add_lines_to_dict
  end

  def songs_exist?
    @songs.length > 0
  end

  def clear_dict
    @dict.clear!
  end

  def create_haiku
    line1 = @dict.generate_n_words(rand(1..7))
    line2 = @dict.generate_n_words(rand(1..7))
    line3 = @dict.generate_n_words(rand(1..7))

    until line1.to_phrase.syllables == 5
      line1 = @dict.generate_n_words(rand(1..5))
    end

    until line2.to_phrase.syllables == 7
      line2 = @dict.generate_n_words(rand(1..7))
    end

    until line3.to_phrase.syllables == 5
      line3 = @dict.generate_n_words(rand(1..5))
    end

    if line3[-1] == ","
      line3[-1] = ""
    end

    return [@artist, line1, line2, line3]
  end

  def get_songs
    @songs = RapGenius.search_by_artist(@artist)
  end

  def add_lines_to_dict
    @songs.each do |song|
      song.lines.each do |line|
        @dict.parse_string(line.lyric) if line.lyric[0] != "["
      end
    end
  end
end

class Formatter
  def self.format_for_twitter(args)
    haiku_array = args[:haiku_array]
    haiku_array.map!{|string| string.downcase}
    artist = "#" + haiku_array.shift.gsub(/\W/, "")
    haiku_array << "\n / #raphaiku / by #{artist}"
    if args[:request]
      haiku_array << "/ requested by @#{args[:request]}"
    end
    return haiku_array.join("\n")
  end

end


class RequestHandler
  attr_reader :mentions, :requests

  def initialize(twitter_client)
    @client = twitter_client
    @requests = []
    get_young_mentions
    parse_all_mentions
  end

  def valid_requests?
    @requests.length > 0
  end

  def parse_all_mentions
    if @mentions.length > 0
      @mentions.each do |mention|
        parsed_request = parse_mention(mention)
        @requests << parsed_request if parsed_request
      end
    end
  end

  def get_young_mentions
    all_mentions = @client.mentions_timeline
    @mentions = all_mentions.select {|mention| mention_is_young_enough?(mention)}
  end

  def parse_mention(mention)
    request = mention.full_text.dup
    capture = request.match(/request\s(.+)/).captures.first if request.match(/request\s(.+)/)
    if capture
      return [capture, mention.user.screen_name]
    else
      return nil
    end
  end

  def mention_is_young_enough?(mention)
    ((Time.now - mention.created_at) / 60) < 10
  end
end

class RapHaikuBot
  def initialize
    @client = configure_twitter_client
  end

  def the_whole_thing
    @handler = RequestHandler.new(@client)
    if @handler.valid_requests?
      @handler.requests.each do |request|
        fulfill_request(request)
      end
    else
      num = rand(0..13)
      if num == 7
        puts "jackpot!"
        random_haiku
      else
        puts "not this time, cowboy"
      end
    end
  end

  def random_haiku
    this_creator = HaikuCreator.new(RAPPERS.sample)
    twitter_haiku = Formatter.format_for_twitter({:haiku_array => this_creator.create_haiku})
    @client.update(twitter_haiku)
  end

  def fulfill_request(request)
    this_creator = HaikuCreator.new(request.first)
    if this_creator.songs_exist?
      arguments = {:haiku_array => this_creator.create_haiku, :request => request.last}
      twitter_haiku = Formatter.format_for_twitter(arguments)
      @client.update(twitter_haiku)
    end
  end
end


def do_it
  bot = RapHaikuBot.new
  bot.the_whole_thing
end

