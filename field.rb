require "listbox"
require "textbox"

class Field
  TYPE_NAMES = [ "Unsigned 8-bit integer", "Unsigned 16-bit integer", "Unsigned 32-bit integer", "Null-terminated string", "Length-prefixed string", "Unicode null-terminated string", "String", "Timestamp (unix)" ]
  TYPES =      [ :uint8,     :uint16,     :uint32,     :ntstring,   :lpstring,   :untstring,  :string,    ]
  TYPES_C =    [ "guint8",   "guint16",   "guint32",   "guint8 *",  "guint8 *",  "gchar *",   "guint8 *", ]
  TYPES_FT =   [ "FT_UINT8", "FT_UINT16", "FT_UINT32", "FT_STRING", "FT_STRING", "FT_STRING", "FT_STRING",] 
  TYPES_BASE = [ "BASE_HEX", "BASE_HEX",  "BASE_HEX",  "BASE_NONE", "BASE_NONE", "BASE_NONE", "BASE_NONE",] 


  ENDIANS      = [ :big_endian, :little_endian,  ]
  ENDIAN_NAMES = [ "Big endian", "Little endian" ]

  OPERATORS    = [ '==', '!=', '&', '|', '^', '>', '>=', '<', '<=' ]

  attr_accessor :name, :order, :parent, :offset, :type, :endian, :colour, :length, :is_optional, :optional_field, :optional_operator, :optional_value

  def initialize(position, type, endian)
    @name        = nil
    @order       = Time.now().to_i
    #@offset      = position
    @type        = type
    @endian      = endian

    @parent      = nil
    @colour      = nil
    @length      = nil

    @optional_field = nil
    @optional_operator = nil
    @optional_value = nil
  end

  def prompt_numeric_value(data, value)
    values = @structure.get_numeric_values(data)
    values.each_pair do |i, v|
      MessageBox.new("%s => %s" % [i, v])
    end
  end

  def self.should_request_length(type)
    case TYPES[type]
      when :string
        return true
      else
        return false
    end
  end
  def should_request_length()
    return Field.should_request_length(@type)
  end

  def self.estimate_field_size(data, type, pos)
    case TYPES[type]
      when :uint8
        return 1
      when :uint16
        return 2
      when :uint32
        return 4
      when :ntstring
        length = 0
        while(get_uint8(data, pos + length) != 0)
          length = length + 1
          if(too_long(data, pos, length))
            return length
          end
        end
        return length + 1
      when :lpstring
        return get_uint8(data, pos) + 1
      when :untstring
        length = 0
        # Note: Endian doesn't matter here since we're looking for 0x0000
        while(get_uint16(data, :little_endian, pos + length) != 0)
          length = length + 2
          if(too_long(data, pos, length))
            return length
          end
        end
        return length + 2
      when :string
        return 1 # We can't guess this one
      else
        throw :unknown_type
    end
  end

  def self.get_preview_value(data, type, endian, pos)
    size = estimate_field_size(data, type, pos)
    if(too_long(data, pos, size))
      return nil
    end

    case TYPES[type]
    when :uint8
      return get_uint8(data, pos)
    when :uint16
      return get_uint16(data, endian, pos)
    when :uint32
      return get_uint32(data, endian, pos)
    when :ntstring
      str = ''
      this_char = get_char(data, pos + str.length)
      while(!this_char.nil? && this_char != ?0)
        str = str + this_char
        if(too_long(data, pos, str.length))
          return nil
        end
      end
      return str
    when :string
      this_char = get_char(data, pos)
      return this_char + "[...]"
    when :lpstring
      return get_bytes(data, size, pos + 1)
    when :untstring
      str = ''
      # Note: Endian doesn't matter here since we're looking for 0x0000
      # Note: We're faking unicode right now - see if we can do it right
      while(get_uint16(data, :little_endian, pos + (str.length * 2)) != 0)
        str = str + get_char(data, pos + (str.length * 2))
        if(too_long(data, pos, str.length * 2))
          return length
        end
      end
      return str
    else
      throw :unknown_type
    end
  end

  def self.value_to_string(value, type)
    if(value.nil?)
      return "<n/a>"
    end

    case type
    when :uint8
      return '0x%02x (%d)' % [value, value]
    when :uint16
      return '0x%04x (%d)' % [value, value]
    when :uint32
      return '0x%08x (%d)' % [value, value]
    when :ntstring, :lpstring, :untstring, :string
      return value.to_s
    else
      throw :unknown_type
    end
  end

  def self.too_long(data, pos, length)
    return data.size < (pos + length)
  end

  def self.get_bytes(data, count, start)
    if(Field.too_long(data, start, count))
      return nil
    end
    return data[start, count]
  end

  def self.get_char(data, pos)
    if(Field.too_long(data, pos, 1))
      return nil
    end

    return data[pos, 1]
  end

  def self.get_uint8(data, pos)
    if(Field.too_long(data, pos, 1))
      return nil
    end

    return data[pos, 1].unpack('C').pop
  end

  def self.get_uint16(data, endian, pos)
    if(Field.too_long(data, pos, 2))
      return nil
    end

    type = endian == :little_endian ? 'v' : 'n'
    return data[pos, 2].unpack(type).pop
  end

  def self.get_uint32(data, endian, pos)
    if(Field.too_long(data, pos, 4))
      return nil
    end

    type = endian == :little_endian ? 'V' : 'N'
    return data[pos, 4].unpack(type).pop
  end

  def self.too_long(data, pos, length)
    return data.size < (pos + length)
  end
end
