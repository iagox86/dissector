require 'ncurses'
require 'pcap'

class Textbox
  def initialize(value)
    value = value || ''

    @value = value
    @window  = Ncurses.newwin(3, 80, 0, 0)
    Ncurses.keypad(@window, true)
    @cursor_pos = value.length
  end

  def display(prompt)
    @window.move(1, 2)
    @window.clrtobot()
    @window.printw("%s%s" % [prompt, @value])
    @window.move(1,2 + prompt.length + @cursor_pos)
    Ncurses.box(@window, 0, 0)
  end

  def prompt(prompt)
    loop do
      Ncurses.curs_set(1)
      display(prompt)
      @window.refresh()

      ch = @window.getch
      case ch
      when Ncurses::KEY_LEFT
        @cursor_pos = [0, @cursor_pos-1].max

      when Ncurses::KEY_RIGHT
        @cursor_pos = [@value.length, @cursor_pos+1].min

      when Ncurses::KEY_ENTER, ?\n, ?\r
        return @value

      when Ncurses::KEY_BACKSPACE
        @value = @value[0...([0, @cursor_pos-1].max)] + @value[@cursor_pos..-1]
        @cursor_pos = [0, @cursor_pos-1].max

      when " "[0]..255 # remaining printables
        @value[@cursor_pos,0] = ch.chr
        @cursor_pos += 1
      else
        Ncurses.beep
      end
    end
  end
end

