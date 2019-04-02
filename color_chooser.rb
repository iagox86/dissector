require 'ncurses'

class ColorChooser
  COLOR_OK    = 0
  COLOR_ERROR = 1

  COLORS = [ 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, ]
  COLOR_NAMES = [ 'Green', 'Yellow', 'Blue', 'Magenta', 'Cyan', 'Inverted green', 'Inverted yellow', 'Inverted blue', 'Inverted magenta', 'Inverted cyan' ]

  @@initialized = false
  @@color = 0

  attr_accessor :color

  def self.initialize()
    if(!@@initialized)
      Ncurses.start_color
      Ncurses.init_pair(COLOR_ERROR, Ncurses::COLOR_WHITE,   Ncurses::COLOR_RED)

      Ncurses.init_pair(COLORS[0],  Ncurses::COLOR_GREEN,   Ncurses::COLOR_BLACK)
      Ncurses.init_pair(COLORS[1],  Ncurses::COLOR_YELLOW,  Ncurses::COLOR_BLACK)
      Ncurses.init_pair(COLORS[2],  Ncurses::COLOR_BLUE,    Ncurses::COLOR_BLACK)
      Ncurses.init_pair(COLORS[3],  Ncurses::COLOR_MAGENTA, Ncurses::COLOR_BLACK)
      Ncurses.init_pair(COLORS[4],  Ncurses::COLOR_CYAN,    Ncurses::COLOR_BLACK)

      Ncurses.init_pair(COLORS[5],  Ncurses::COLOR_BLACK, Ncurses::COLOR_GREEN)
      Ncurses.init_pair(COLORS[6],  Ncurses::COLOR_BLACK, Ncurses::COLOR_YELLOW)
      Ncurses.init_pair(COLORS[7],  Ncurses::COLOR_BLACK, Ncurses::COLOR_BLUE)
      Ncurses.init_pair(COLORS[8], Ncurses::COLOR_BLACK, Ncurses::COLOR_MAGENTA)
      Ncurses.init_pair(COLORS[9], Ncurses::COLOR_BLACK, Ncurses::COLOR_CYAN)


    end
  end

  def self.color=(color)
    @@color = color
  end
  def self.color()
    return @@color
  end

  def initialize(color)
    @color = COLORS.find_index(color)
    if(@color.nil?)
      @color = @@color
      @@color = (@@color + 1) % COLORS.size
    end

    @window  = Ncurses.newwin(3, 80, 0, 0)
    Ncurses.keypad(@window, true)
  end

  def display(prompt)
    @window.move(1, 2)
    @window.clrtobot()
    @window.printw(" %s" % prompt)
    @window.color_set(COLORS[@color], nil)
    @window.printw("%s" % [COLOR_NAMES[@color]])
    @window.color_set(COLOR_OK, nil)
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
        @color -= 1
        if(@color < 0)
          @color = COLORS.size - 1
        end

      when Ncurses::KEY_RIGHT
        @color += 1
        if(@color >= COLORS.size)
          @color = 0
        end

      when Ncurses::KEY_ENTER, ?\n, ?\r
        return COLORS[@color]

      else
        Ncurses.beep
      end
    end
  end
end

