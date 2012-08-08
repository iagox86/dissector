require 'field'
require 'hex'
require 'hex_window'
require 'structure'

class Packet
  @@field = 1
  attr_reader :structure

  def initialize(data, structure)
    @hex_window = HexWindow.new(0, 0, data, false)
    @data       = data
    @structure  = structure
  end

  def go()
    loop do
      @hex_window.clear_fields()
      @structure.each_position_length_field(@data) do |position, length, field|
        @hex_window.add_field(field.name, position, length, field.colour)
      end

      pos, type, endian = @hex_window.get_input()

      if(pos.nil?)
        return
      end
      @structure.edit_field(@data, pos, type, endian)
    end
  end

end
  

