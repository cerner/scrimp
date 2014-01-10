module Scrimp
  # Generated Thrift struct classes can extend this module to gain a #from_hash method that will build
  # them from a hash representation. The hash representation uses only types that can be readily converted to/from json.
  # See the README's "JSON Representation" section.
  module JsonThrift
    # Construct a new instance of the class extending this module and populate its fields with values from a hash.
    #
    # @param [Hash] hash populates fields of the Thrift struct that have names that match its keys (string keys only)
    # @return [Thrift::Struct]
    # @raise [Thrift::TypeError] if one of the values in +hash+ is not a valid type for its field or a field exists with
    #                            an invalid type
    def from_hash(hash)
      thrift_struct = self.new

      hash.each do |(k, v)|
        field = thrift_struct.struct_fields.find {|sk,sv| sv[:name] == k}.last
        value = json_type_to_thrift_type(v, field)
        Thrift.check_type(value, field, field[:name]) # raises Thrift::TypeError if value is the wrong type
        thrift_struct.send("#{field[:name]}=", value)
      end

      thrift_struct
    end

    # Converts +value+ to a Thrift type that can be passed to a Thrift setter for the given +field+.
    #
    # @param [Object] value the parsed json type to be converted
    # @param [Hash] field the Thrift field that will accept +value+
    # @return [Object] +value+ converted to a type that the setter for +field+ will expect
    # @raise [Thrift::TypeError] if +field+ has an invalid type
    def json_type_to_thrift_type(value, field)
      type = Thrift.type_name(field[:type])
      raise Thrift::TypeError.new("Type for #{field.inspect} not found.") unless type
      type.sub!('Types::', '')
      v = value
      if type == 'STRUCT'
        v = field[:class].from_hash(v)
      elsif [Thrift::Types::LIST, Thrift::Types::MAP, Thrift::Types::SET].include? field[:type]
        if type == 'MAP'
          # JSON doesn't allow arbitrary keys in objects, so maps will be represented
          # by a vector of key-value pairs
          v = {}
          value.each do |(key, value)|
            thrift_key = json_type_to_thrift_type(key, field[:key])
            thrift_value = json_type_to_thrift_type(value, field[:value])
            v[thrift_key] = thrift_value
          end
        else
          v = value.collect{|e| json_type_to_thrift_type(e, field[:element])}
          v = Set.new(v) if type == 'SET'
        end
      elsif type == 'DOUBLE'
        v = v.to_f
      elsif field[:enum_class] && value.to_i != value
        v = field[:enum_class].const_get('VALUE_MAP').invert[value] || value
      # TODO: STOP, VOID, BYTE
      end
      v
    end
  end
end