require 'colour_chooser'
require 'field'
require 'hex'
require 'structure'

require 'ncurses'

class HexWindow
  attr_reader :window
  def initialize(y, x, data, display_only)
    @hex            = Hex.new(data)
    @y              = y
    @x              = x
    @data           = data
    @display_only   = display_only
    @current_type   = 0
    @current_endian = 0
    @key_callbacks  = {}

    @fields         = {}

    @y_offset       = @display_only ? 1 : 3
    @x_offset       = 1 # For the border
    @rows           = Ncurses.stdscr.getmaxy - y # @hex.lines + (@display_only ? 4 : 10)
    @cols           = 80 - x

    @window  = Ncurses.newwin(@rows, @cols, y, x)

    Ncurses.keypad(@window, true)
  end

  def add_key_callback(key, callback)
    @key_callbacks[key] = callback
  end

  def draw()
    @window.move(0, 0)

    # Do the title
    @window.printw("\n") # The border
    if(!@display_only)
      @window.printw(" Press <backspace> or <escape> to go back\n\n")
    end

    # Print the hex
    @hex.get_str.split("\n").each do |line|
      @window.printw(' ' + line.gsub('%', '%%') + "\n")
    end
    @window.printw("\n")

    if(!@display_only)
#      @window.clrtobot()
#      # Print the type and endianness values
#      @window.printw(" Type: ")
#      @window.attron(Ncurses::A_BOLD)
#      @window.printw("%s " % Field::TYPE_NAMES[@current_type])
#      @window.attroff(Ncurses::A_BOLD)
#      @window.printw("(tab/home/end to change)\n")
#
#      @window.printw(" Endian: ")
#      @window.attron(Ncurses::A_BOLD)
#      @window.printw("%s " % Field::ENDIAN_NAMES[@current_endian])
#      @window.attroff(Ncurses::A_BOLD)
#      @window.printw("(pgup/pgdown to change)\n")
#      @window.printw("\n")
#
#      # Get the value
#      value = Field.get_preview_value(@data, @current_type, Field::ENDIANS[@current_endian], @hex.pos)
#      #@window.printw("\n");
#      if(value.nil?)
#        @window.printw(" Value: %s\n" % '<invalid value>');
#      else
#        @window.printw(" Value: %s\n" % Field.value_to_string(value, Field::TYPES[@current_type]).gsub('%', '%%'));
#      end

      # If we're sitting on a defined field, display the information
      field = get_current_field()
      if(!field.nil?)
        @window.printw(" Selected field:\n")
        @window.printw("  Name:   %s\n" % field[:name])
        @window.printw("  Pos:    %s\n" % field[:position])
        @window.printw("  Size:   %s\n" % field[:size]) # TODO: Make this a 'pretty' string representation
      else
        @window.printw(" Selected field:\n")
        @window.printw("  n/a\n")
        @window.printw("\n")
        @window.printw("\n")
      end
    end

    # Print all the fields we know of (TODO: get a proper value somehow)
    @window.printw("\n")
    @window.printw(" Fields:\n")
    @fields.each_pair do |name, field|
      @window.printw("  %s => pos: %s, size: %s\n" % [name, field[:position], field[:size]])
    end

    # Remove any highlighting
    0.upto(@data.size) do |i|
      hex_y,   hex_x   = Hex.get_hex_coordinates(i)
      ascii_y, ascii_x = Hex.get_ascii_coordinates(i)

      @window.mvchgat(hex_y   + @y_offset, hex_x   + @x_offset,     1, Ncurses::A_NORMAL, ColourChooser::COLOUR_OK, nil)
      @window.mvchgat(hex_y   + @y_offset, hex_x   + @x_offset + 1, 1, Ncurses::A_NORMAL, ColourChooser::COLOUR_OK, nil)
      @window.mvchgat(ascii_y + @y_offset, ascii_x + @x_offset,     1, Ncurses::A_NORMAL, ColourChooser::COLOUR_OK, nil)
    end

    # Mark all defined fields (this should happen before highlighting)
    @fields.each() do |name, field|
        field[:position].upto(field[:position] + field[:size] - 1) do |i|
          hex_y,   hex_x   = Hex.get_hex_coordinates(i)
          ascii_y, ascii_x = Hex.get_ascii_coordinates(i)

          @window.mvchgat(hex_y   + @y_offset, hex_x   + @x_offset,     1, Ncurses::A_NORMAL, field[:colour], nil)
          @window.mvchgat(hex_y   + @y_offset, hex_x   + @x_offset + 1, 1, Ncurses::A_NORMAL, field[:colour], nil)
          @window.mvchgat(ascii_y + @y_offset, ascii_x + @x_offset,     1, Ncurses::A_NORMAL, field[:colour], nil)
        end
    end

    # Find any overlapping sections and mark them as errors
    overlaps = get_overlapping_indexes()
    overlaps.each do |i|
      hex_y,   hex_x   = Hex.get_hex_coordinates(i)
      ascii_y, ascii_x = Hex.get_ascii_coordinates(i)

      @window.mvchgat(hex_y   + @y_offset, hex_x   + @x_offset,     1, Ncurses::A_NORMAL, ColourChooser::COLOUR_ERROR, nil)
      @window.mvchgat(hex_y   + @y_offset, hex_x   + @x_offset + 1, 1, Ncurses::A_NORMAL, ColourChooser::COLOUR_ERROR, nil)
      @window.mvchgat(ascii_y + @y_offset, ascii_x + @x_offset,     1, Ncurses::A_NORMAL, ColourChooser::COLOUR_ERROR, nil)
    end


    if(!@display_only)
      field = get_current_field()

      highlight_start = 0
      highlight_length = 0
      if(field) # Highlight the full field
        highlight_start  = field[:position]
        highlight_length = field[:size]
        colour = field[:colour] || ColourChooser::COLOUR_OK
      else # Only highlight the current position
        highlight_start = @hex.pos
        highlight_length = 1
        colour = ColourChooser::COLOUR_OK
      end

      highlight_start.upto(highlight_start + highlight_length - 1) do |i|
        if(i < @data.size)
          hex_y,   hex_x   = Hex.get_hex_coordinates(i)
          ascii_y, ascii_x = Hex.get_ascii_coordinates(i)
 
          @window.mvchgat(hex_y   + @y_offset, hex_x   + @x_offset,     1, Ncurses::A_REVERSE, colour, nil)
          @window.mvchgat(hex_y   + @y_offset, hex_x   + @x_offset + 1, 1, Ncurses::A_REVERSE, colour, nil)
          @window.mvchgat(ascii_y + @y_offset, ascii_x + @x_offset,     1, Ncurses::A_REVERSE, colour, nil)
        end
      end
    end


    # This adds the border
    Ncurses.box(@window, 0, 0)
    @window.refresh
  end

  # Add a field to the hex window so it can be highlighted. This will have
  # no actual information about the field, and should be considered 'dumb'. 
  def add_field(name, position, size, colour)
    @fields[name] = { :name => name, :position => position, :size => size, :colour => colour }
  end

  def clear_fields() 
    @fields = {}
  end

  def get_field_at(pos)
    @fields.each_value() do |field|
      if(pos >= field[:position] && pos < field[:position] + field[:size])
        return field
      end
    end

    return nil
  end

  def get_current_field()
    return get_field_at(@hex.pos)
  end

  def get_previous_field()
    return get_field_at(@hex.old_pos)
  end

  # Return a list of all indexes in data that have two or more fields
  def get_overlapping_indexes()
    indexes = {}
    @fields.each_pair do |name, field|
      field[:position].upto(field[:position] + field[:size] - 1) do |i|
        indexes[i] = (indexes[i].nil?) ? 1 : (indexes[i] + 1)
      end
    end

    overlaps = []
    indexes.each_pair() do |i, v|
      if(v > 1)
        overlaps << i
      end
    end

    return overlaps
  end


  def get_input
    if(@display_only)
      throw :you_cant_call_that
    end

    loop do
      Ncurses.curs_set(0)

      draw()

      ch = @window.getch
      case ch
      when Ncurses::KEY_LEFT
        begin
          @hex.go_left
          new_field = get_current_field()
          old_field = get_previous_field()
        end while((new_field == old_field && !new_field.nil? && !old_field.nil?) && @hex.old_pos != @hex.pos)

      when Ncurses::KEY_RIGHT

        begin
          @hex.go_right
          new_field = get_current_field()
          old_field = get_previous_field()
        end while((new_field == old_field && !new_field.nil? && !old_field.nil?) && @hex.old_pos != @hex.pos)

      when Ncurses::KEY_UP
        @hex.go_up
      when Ncurses::KEY_DOWN
        @hex.go_down

      when Ncurses::KEY_NPAGE
        @current_endian = (@current_endian - 1) % Field::ENDIANS.length
      when Ncurses::KEY_PPAGE
        @current_endian = (@current_endian + 1) % Field::ENDIANS.length

      when Ncurses::KEY_HOME
        @current_type = (@current_type - 1) % Field::TYPES.length
      when Ncurses::KEY_END, Ncurses::KEY_TAB, ?\t
        @current_type = (@current_type + 1) % Field::TYPES.length

      when Ncurses::KEY_BACKSPACE, Ncurses::KEY_ESCAPE
        return nil

      when ?d, ?D
        field = @structure.get_field_at(@data, @hex.pos)
        if(!field.nil?)
          children = @structure.get_children(field)
          if(children.size == 0)
            @structure.delete_field(@structure.get_field_at(@data, @hex.pos))
          else
            MessageBox.new("Can't delete #{field.name}; the following fields depend on it:\n#{children.join("\n")}", "Error!").go()
          end
        end

      when ?e, ?E
        @structure.choose_edit_field(@data)

      when ?r, ?R
        field = @structure.get_field_at(@data, @hex.pos)
        if(field.nil?)
          Ncurses.beep
        else
          old_name = String.new(field.name)
          new_name = Textbox.new(field.name).prompt("Please enter the name --> ")
          if(!new_name.nil?)
            @structure.rename_field(old_name, new_name)
          end
        end

      when Ncurses::KEY_ENTER, ?\r, ?\n
        if(Field.too_long(@data, @hex.pos, Field.estimate_field_size(@data, @current_type, @hex.pos)))
          Ncurses.beep
        else
          return [@hex.pos, @current_type, @current_endian]
        end
      else
        if(@key_callbacks.nil? || @key_callbacks[ch].nil?)
          Ncurses.beep
        else
          @key_callbacks[ch].call()
        end
      end # switch
    end
  end

  def closeWindow
    @window.delwin();
  end
end

