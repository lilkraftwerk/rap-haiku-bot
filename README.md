rap-haiku-bot
=============

http://twitter.com/rap_haiku

randomly generated haikus from rappers

takes requests via "@rap_haiku request [rapper name goes here]"

if no recent requests, will randomly pick from a preset list of rappers and make a haiku.

uses the rapgenius gem to gather lyrics from a given artist, and then feeds them into the marky markov gem to create markov chains. generates random short sentences until they meet the 5-7-5 format (checking number of syllables with the ruby_rhymes gem) and then uploads to twitter.

holler
