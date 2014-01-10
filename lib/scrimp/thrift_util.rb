# coding: UTF-8

module Scrimp
  module ThriftUtil
    class << self
      # use a fully-qualified name to get a constant
      # no, it really doesn't belong here
      # but life will almost certainly go on
      def qualified_const(name)
        name.split('::').inject(Object) {|obj, name| obj.const_get(name)}
      end

      def application_exception_type_string(type)
        case type
        when Thrift::ApplicationException::UNKNOWN
          'UNKNOWN'
        when Thrift::ApplicationException::UNKNOWN_METHOD
          'UNKNOWN_METHOD'
        when Thrift::ApplicationException::INVALID_MESSAGE_TYPE
          'INVALID_MESSAGE_TYPE'
        when Thrift::ApplicationException::WRONG_METHOD_NAME
          'WRONG_METHOD_NAME'
        when Thrift::ApplicationException::BAD_SEQUENCE_ID
          'BAD_SEQUENCE_ID'
        when Thrift::ApplicationException::MISSING_RESULT
          'MISSING_RESULT'
        when Thrift::ApplicationException::INTERNAL_ERROR
          'INTERNAL_ERROR'
        when Thrift::ApplicationException::PROTOCOL_ERROR
          'PROTOCOL_ERROR'
        else
          type
        end
      end

      # For every Thrift service, the code generator produces a module. This
      # returns a list of all such modules currently loaded.
      def service_modules
        modules = []
        ObjectSpace.each_object(Module) do |clazz|
          if clazz < Thrift::Client
            modules << qualified_const(clazz.name.split('::')[0..-2].join('::')) # i miss activesupport...
          end
        end
        modules.delete(Thrift)
        modules
      end

      # Given a service module (see service_modules above), returns a list of the names of all
      # the functions of that Thrift service.
      def service_functions(service_module)
        methods = service_module.const_get('Client').instance_methods.map {|method| method.to_s}
        methods.select do |method|
          send_exists = methods.include? "send_#{method}"
          upped = method.dup
          upped[0..0] = method[0..0].upcase
          begin
            send_exists && service_module.const_get("#{upped}_args")
          rescue
            false
          end
        end
      end

      # Given a service module (see service_modules above) and a Thrift function name,
      # returns the class for the structure representing the function's arguments.
      def service_args(service_module, function_name)
        function_name = function_name.dup
        function_name[0..0] = function_name[0..0].upcase
        service_module.const_get("#{function_name}_args")
      end

      # Given a service module (see service_modules above) and a Thrift function name,
      # returns the class for the structure representing the function's return value.
      def service_result(service_module, function_name)
        function_name = function_name.dup
        function_name[0..0] = function_name[0..0].upcase
        service_module.const_get("#{function_name}_result")
      end

      # Returns a list of the classes for all Thrift structures that were loaded
      # at the time extend_structs was called (see below).
      def all_structs
        @@all_structs
      end

      # Finds all loaded Thrift struct classes, adds methods to them
      # for building them from hashes, and saves the list of them for
      # future reference.
      def extend_structs
        @@all_structs = []
        ObjectSpace.each_object(Module) do |clazz|
          if Thrift::Struct > clazz || Thrift::Union > clazz
            clazz.extend(JsonThrift)
            @@all_structs << clazz
          end
        end
      end

      # Converts a Thrift struct to a hash (suitable for conversion to json).
      def thrift_struct_to_json_map(value, clazz)
        result = {}
        clazz.const_get('FIELDS').each do |(_, struct_field)|
          name = struct_field[:name]
          val = value.send(name)
          result[name] = thrift_type_to_json_type(val, struct_field) if val
        end
        result
      end

      # Converts a Thrift union to a hash (suitable for conversion to json).
      def thrift_union_to_json_map(value, clazz)
        result = {}
        name = value.get_set_field.to_s
        struct_field = clazz.const_get('FIELDS').find{|x| x[1][:name] == name}[1]
        result[name] = thrift_type_to_json_type(value.get_value, struct_field)
        result
      end

      # Converts a Thrift value to a primitive, list, or hash (suitable for conversion to json).
      # The value is interpreted using a type info hash of the format returned by #type_info.
      def thrift_type_to_json_type(value, field)
        type = Thrift.type_name(field[:type])
        raise Thrift::TypeError.new("Type for #{field.inspect} not found.") unless type
        type.sub!('Types::', '')
        result = value
        type = 'UNION' if type == 'STRUCT' && field[:class].ancestors.any?{|x| x == Thrift::Union}
        if type == 'STRUCT'
          result = thrift_struct_to_json_map(value, field[:class])
          # field[:class].const_get('FIELDS').each do |(_, struct_field)|
          #   name = struct_field[:name]
          #   val = value.send(name)
          #   result[name] = thrift_type_to_json_type(val, struct_field) if val
          # end
        elsif type == 'LIST' || type == 'SET'
          result = value.map {|val| thrift_type_to_json_type val, field[:element]}
        elsif type == 'MAP'
          result = value.map do |key, val|
            [thrift_type_to_json_type(key, field[:key]), thrift_type_to_json_type(val, field[:value])]
          end
        elsif enum = field[:enum_class]
          result = enum.const_get('VALUE_MAP')[value] || value
        elsif type == 'UNION'
          result = thrift_union_to_json_map(value, field[:class])
        end
        result
      end

      # Given a field description (as found in the FIELDS constant of a Thrift struct class),
      # returns a hash containing these elements:
      # - type - the name of the type, such as UNION, STRUCT, etc
      # - key (for maps) - the type info hash of the map's keys
      # - value (for maps) - the type info hash of the map's values
      # - element (for lists, sets) - the type info hash of the collection's elements
      # - enum (for enums) - a map of enum numeric value to name for the enum values
      def type_info(field)
        field = field.dup
        field[:type] = Thrift.type_name(field[:type]).sub('Types::', '')
        field.delete :name
        field[:key] = type_info(field[:key]) if field[:key]
        field[:value] = type_info(field[:value]) if field[:value]
        field[:element] = type_info(field[:element]) if field[:element]
        if enum = field[:enum_class]
          field[:enum] = enum.const_get 'VALUE_MAP'
        end
        field
      end
    end
  end
end

