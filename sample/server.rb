#!/usr/bin/env ruby

require 'optparse'
require 'tmpdir'
require 'thrift'

options = {port: 9000,
           thrift_command: 'thrift'}
parser = OptionParser.new do |op|
  op.on '-p', '--port PORT', 'port to launch Thrift server on' do |port|
    options[:port] = port.to_i
  end
  op.on '-t', '--thrift-command COMMAND', 'thrift compiler' do |cmd|
    options[:thrift_command] = cmd
  end
  op.on '-h', '--help' do
    puts parser
    exit 0
  end
end

begin
  parser.parse!
rescue
  puts parser
  exit 0
end

Dir.mktmpdir do |out|
  path = File.expand_path(File.join(File.dirname(__FILE__), 'example.thrift'))
  puts (cmd = "#{options[:thrift_command]} --gen rb --out #{out} #{path}")
  puts `#{cmd}`
  $LOAD_PATH.unshift out
  Dir["#{out}/*.rb"].each {|file| require file}
  $LOAD_PATH.delete out
end

class ExampleServiceImpl
  include ExampleService

  # Example with map and struct in response.
  def textStats(text)
    words = text.split(/\b/).map {|w| w.gsub(/\W/, '').downcase}.reject(&:empty?)
    results = {}
    words.uniq.each do |word|
      results[word] = WordStats.new count: words.count(word),
                                    percentage: words.count(word).to_f / words.count.to_f,
                                    palindrome: word == word.reverse
    end
    results
  end

  # Example with set, struct, and optional field in request.
  GREETINGS = {1 => "Stay warm!",
               2 => "Watch out for eldritch horrors!",
               3 => "Try to calm down."}
  def greet(people)
    str = ""
    people.each do |person|
      str << "Hello, #{person.name}! #{GREETINGS[person.favoriteWord]}\n"
    end
    str
  end

  # Example with no request params.
  def random
    rand
  end

  def voidMethod(throwException)
    raise Tantrum.new("We're out of hot chocolate!") if throwException
  end

  def onewayMethod(message)
    puts "I received the following message, which I fully intend to ignore: #{message}"
  end
end

processor = ExampleServiceImpl::Processor.new(ExampleServiceImpl.new)
transport = Thrift::ServerSocket.new('localhost', options[:port])
transport_factory = Thrift::FramedTransportFactory.new
protocol_factory = Thrift::CompactProtocolFactory.new
server = Thrift::SimpleServer.new(processor, transport, transport_factory, protocol_factory)

puts "Starting example service for localhost on port #{options[:port]}"
server.serve
