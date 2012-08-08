require 'ncurses'
require 'pcap'

class MessageBox
  # list can be:
  # A hash (where the keys will be the values returned and the values will be
  #  the names displayed. Note - these will not be in order
  # An array (where each element is a string and each value is its index
  # An array of hashes (where each hash contains a :name and :value)
  def initialize(text, title = nil, width = 59)
    @title  = title
    @width  = [width  + 2, Ncurses.stdscr.getmaxx].min

    @text   = MessageBox.split_lines(text, width)

    @height = @text.size + 4

    @window  = Ncurses.newwin(@height, @width, 0, 0)
    Ncurses.keypad(@window, true)
  end

  def self.split_lines(text, width)
    return text.gsub(/(.{1,#{width}})(\s+|$)/,"\\1\n").split("\n")
  end

  def display()

    @window.box(0, 0)
    @window.move(0, 0)
    if(@title)
      @window.printw("%s" % @title)
    end

    @text.each_with_index do |line, index| 
      @window.move(index + 1, (@width / 2) - (line.length / 2))
      @window.printw("%s" % line)
    end

    text = "Ok"
    @window.attron(Ncurses::A_REVERSE)
    @window.move(@height - 2, (@width / 2) - (text.length / 2))
    @window.printw("%s" % text)
    @window.attroff(Ncurses::A_REVERSE)
  end

  def go()
    @window.clear()

    loop do
      Ncurses.curs_set(0);
      display()

      ch = @window.getch
      case ch
      when Ncurses::KEY_ENTER, ?\n, ?\r, Ncurses::KEY_ESCAPE, Ncurses::KEY_BACKSPACE
        @window.clear()
        @window.refresh()
        return
      else
        Ncurses.beep
      end
    end
  end
end

