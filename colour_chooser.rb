require 'ncurses'

class ColourChooser
  COLOUR_OK    = 0
  COLOUR_ERROR = 1

  COLOURS = [ 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, ]
  COLOUR_NAMES = [ 'Green', 'Yellow', 'Blue', 'Magenta', 'Cyan', 'Inverted green', 'Inverted yellow', 'Inverted blue', 'Inverted magenta', 'Inverted cyan' ]

  @@initialized = false
  @@colour = 0

  attr_accessor :colour

  def self.initialize()
    if(!@@initialized)
      Ncurses.start_color
      Ncurses.init_pair(COLOUR_ERROR, Ncurses::COLOR_WHITE,   Ncurses::COLOR_RED)

      Ncurses.init_pair(COLOURS[0],  Ncurses::COLOR_GREEN,   Ncurses::COLOR_BLACK)
      Ncurses.init_pair(COLOURS[1],  Ncurses::COLOR_YELLOW,  Ncurses::COLOR_BLACK)
      Ncurses.init_pair(COLOURS[2],  Ncurses::COLOR_BLUE,    Ncurses::COLOR_BLACK)
      Ncurses.init_pair(COLOURS[3],  Ncurses::COLOR_MAGENTA, Ncurses::COLOR_BLACK)
      Ncurses.init_pair(COLOURS[4],  Ncurses::COLOR_CYAN,    Ncurses::COLOR_BLACK)

      Ncurses.init_pair(COLOURS[5],  Ncurses::COLOR_BLACK, Ncurses::COLOR_GREEN)
      Ncurses.init_pair(COLOURS[6],  Ncurses::COLOR_BLACK, Ncurses::COLOR_YELLOW)
      Ncurses.init_pair(COLOURS[7],  Ncurses::COLOR_BLACK, Ncurses::COLOR_BLUE)
      Ncurses.init_pair(COLOURS[8], Ncurses::COLOR_BLACK, Ncurses::COLOR_MAGENTA)
      Ncurses.init_pair(COLOURS[9], Ncurses::COLOR_BLACK, Ncurses::COLOR_CYAN)


    end
  end

  def self.colour=(colour)
    @@colour = colour
  end
  def self.colour()
    return @@colour
  end

  def initialize(colour)
    @colour = COLOURS.find_index(colour)
    if(@colour.nil?)
      @colour = @@colour
      @@colour = (@@colour + 1) % COLOURS.size
    end

    @window  = Ncurses.newwin(3, 80, 0, 0)
    Ncurses.keypad(@window, true)
  end

  def display(prompt)
    @window.move(1, 2)
    @window.clrtobot()
    @window.printw(" %s" % prompt)
    @window.color_set(COLOURS[@colour], nil)
    @window.printw("%s" % [COLOUR_NAMES[@colour]])
    @window.color_set(COLOUR_OK, nil)
    Ncurses.box(@window, 0, 0)
  end

  def prompt(prompt)
    loop do
      Ncurses.curs_set(0)
      display(prompt)
      @window.refresh()

      ch = @window.getch
      case ch
      when Ncurses::KEY_LEFT
        @colour -= 1
        if(@colour < 0)
          @colour = COLOURS.size - 1
        end

      when Ncurses::KEY_RIGHT
        @colour += 1
        if(@colour >= COLOURS.size)
          @colour = 0
        end

      when Ncurses::KEY_ENTER, ?\n, ?\r
        return COLOURS[@colour]

      else
        Ncurses.beep
      end
    end
  end
end

