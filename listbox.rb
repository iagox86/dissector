require 'ncurses'
require 'pcap'
require 'messagebox'
require 'textbox'

class Listbox
  # choices can be:
  # A hash (where the keys will be the values returned and the values will be
  #  the names displayed. Note - these will not be in order
  # An array (where each element is a string and each value is its index
  # An array of hashes (where each hash contains a :name and :value)
  def initialize(value, choices, allow_custom = false, height = Ncurses.stdscr.getmaxy, width = 80)
    @height   = [height, choices.length + (allow_custom ? 1 : 0)].min
    @width    = [width  + 2, Ncurses.stdscr.getmaxx].min
    @viewport = 0

    @window  = Ncurses.newwin(@height + 4, @width, 0, 0)
    Ncurses.keypad(@window, true)
    @choices = []
    @index = nil

    # Handle an array
    if(choices.is_a?(Array))
      # Only set the value if it's actually in the array (helps handle custom and/or errors)
      if(!value.nil? && (!value.is_a?(Fixnum) || !choices[value].nil?))
        @index = value
      end

      choices.each_with_index do |v, i|
        if(v.is_a?(Hash))
          @choices << v
        else
          @choices << {:name => v.to_s, :value => i}
        end
      end
    elsif(choices.is_a?(Hash))
      choices.each_pair do |k, v|
        if(k == value)
          @index = @choices.length
        end
        @choices << {:name => v, :value => k }
      end
    else
      throw :unknown_type
    end

    # If we allow custom, try and set the index that way
    if(allow_custom)
      if(@index.nil? && !value.nil?)
        @index = choices.length
        @custom_value = value
      end

      @choices << {:name => "Custom... %s" % (@custom_value.nil? ? '' : ('(currently: %s)' % @custom_value)), :value => self}
    end

    # Set a default index
    if(@index.nil?)
      @index = 0
    end
  end

  def add_preview_callback(preview_callback)
    @preview = preview_callback
  end

  def add_key_callback(key, callback)
    if(@key_callbacks.nil?)
      @key_callbacks = {}
    end

    @key_callbacks[key] = callback
  end

  def display(prompt)
    i = 0
    @window.move(1, 0)

    if(prompt)
      @window.printw(" %s\n\n" % prompt)
    end

    found_index = false
    count = 0
    @choices.each_with_index do |element, i|
      count = count + 1
      if(count > @viewport)
        if(i == @index)
          @window.attron(Ncurses::A_REVERSE)
          found_index = true
        end
        @window.printw(" %s\n" % element[:name].gsub('%', '%%').gsub("\x00", ''))
        @window.attroff(Ncurses::A_REVERSE)
      end
    end
    @window.box(0, 0)

    if(!@preview.nil?)
      @preview.call(@height + 4, 0, @choices[@index][:value])
    end
#    @window.clrtobot()
#    if(@choices[@index].is_a?(Hash))
#      @window.printw("\n%s\n" % @choices[@index][:details])
#    end

  end

  def list_swap(a, b)
    temp = @choices[a]
    @choices[a] = @choices[b]
    @choices[b] = temp
  end

  # Get the index of the requested value (used when swapping
  def get_index(value)
    @choices.each_with_index do |choice, index|
      if(choice[:value] == value)
        return index
      end
    end
  end

  def update_viewport()
    if(!@index.is_a?(Fixnum))
      MessageBox.new("Index = #{@index.to_s}").go
    end

    if(@index < @viewport)
      @viewport = @index
    end

    if(@index > (@viewport + @height - 1))
      @viewport = @index - @height + 1
    end
  end

  def prompt(prompt)
    @window.clear()

    loop do
      Ncurses.curs_set(0);
      update_viewport()
      display(prompt)

      ch = @window.getch
      case ch
      when Ncurses::KEY_UP
        @index = (@index - 1) % @choices.size
      when Ncurses::KEY_DOWN
        @index = (@index + 1) % @choices.size
      when Ncurses::KEY_NPAGE
        if(@choices.size > 1 && @index < @choices.size - 1)
          list_swap(@index, @index + 1)
          @index += 1
        end
      when Ncurses::KEY_PPAGE
        if(@choices.size > 1 && @index > 0)
          list_swap(@index, @index - 1)
          @index -= 1
        end
      when Ncurses::KEY_TAB, Ncurses::KEY_ENTER, ?\n, ?\r
        @window.clear()
        @window.refresh()

        if(@choices[@index].is_a?(Hash) && @choices[@index][:value] == self)
          return Textbox.new(@custom_value.nil? ? '' : @custom_value.to_s).prompt(prompt);
        elsif(@choices[@index].is_a?(Hash))
          return @choices[@index][:value]
        else
          return @index
        end
      when Ncurses::KEY_ESCAPE, Ncurses::KEY_BACKSPACE
        @window.clear()
        @window.refresh()
        return nil
      else
        if(!@key_callbacks.nil? && !@key_callbacks[ch].nil?)
          if(@key_callbacks[ch].call(@choices[@index][:value]) == true)
            return
          end
        else
          Ncurses.beep
        end
      end # switch
    end # loop
  end
end

