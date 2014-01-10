# coding: UTF-8

require 'json'
require 'sinatra/base'

module Scrimp
  class App < Sinatra::Base
    set :static, true
    set :public, File.expand_path('../public', __FILE__)
    set :views, File.expand_path('../views', __FILE__)
    set :haml, :format => :html5

    get '/' do
      haml :index
    end

    get '/services' do
      response_map = {}
      ThriftUtil.service_modules.each do |service|
        functions = {}
        ThriftUtil.service_functions(service).each do |function|
          result_fields = ThriftUtil.service_result(service, function).const_get('FIELDS').dup
          if result_fields.empty? || result_fields.all? {|_, field| field[:class] && ThriftUtil.qualified_const(field[:class].to_s) < Thrift::Exception}
            returns = {type: 'VOID'}
          else
            returns = ThriftUtil.type_info(result_fields.delete(0)) # TODO shouldn't assume first is return?
          end
          throws = {}
          result_fields.each do |(_, field)|
            throws[field[:name]] = ThriftUtil.type_info field
          end

          args_fields = ThriftUtil.service_args(service, function).const_get('FIELDS')
          args = {}
          args_fields.each do |(_, field)|
            args[field[:name]] = ThriftUtil.type_info field
          end
          functions[function] = {
            :returns => returns,
            :throws => throws,
            :args => args
          }
        end
        response_map[service] = functions
      end

      content_type :json
      response_map.to_json
    end

    get '/protocols' do
      protocols = {'Thrift::CompactProtocol'=>'Thrift::CompactProtocol',
                   'Thrift::BinaryProtocol'=>'Thrift::BinaryProtocol'}
      content_type :json
      protocols.to_json
    end

    get '/structs' do
      structs = {}
      ThriftUtil.all_structs.each do |struct|
        fields = {}
        struct.const_get('FIELDS').each do |(_, field)|
          fields[field[:name]] = ThriftUtil.type_info(field)
        end
        structs[struct] = fields
      end
      content_type :json
      structs.to_json
    end

    post '/invoke' do
      response_map = {}

      if request.content_type == 'application/x-www-form-urlencoded' # yes it's lame
        invocation = JSON.parse params['request-json']
      else
        invocation = JSON.parse request.body.read
      end
      service_class = ThriftUtil.qualified_const invocation['service']
      args_class = ThriftUtil.service_args service_class, invocation['function']
      result_class = ThriftUtil.service_result service_class, invocation['function']

      args = args_class.const_get('FIELDS').sort.map do |(_, field_info)|
        arg = invocation['args'][field_info[:name]]
        if arg != nil
          args_class.json_type_to_thrift_type arg, field_info
        end
      end.compact

      begin
        transport = Thrift::FramedTransport.new Thrift::Socket.new(invocation['host'], invocation['port'])
        protocol_class = ThriftUtil.qualified_const invocation['protocol']
        protocol = protocol_class.new transport
        client = service_class.const_get('Client').new protocol
        transport.open
        result = client.send invocation['function'], *args
        if return_type = result_class.const_get('FIELDS')[0]
          response_map[:return] = ThriftUtil.thrift_type_to_json_type result, return_type
        else # void
          response_map[:return] = nil
        end
      rescue Thrift::ApplicationException => ex
        response_map[ex.class] = {
          :type => ThriftUtil.application_exception_type_string(ex.type),
          :message => ex.message
        }
      rescue Thrift::Exception => ex
        # this is untested
        raise ex unless ex.class < Thrift::Struct
        response_map[ex.class] = ThriftUtil.thrift_struct_to_json_map(ex, ex.class)
      ensure
        transport.close if transport
      end

      content_type :json
      response_map.to_json
    end
  end
end
