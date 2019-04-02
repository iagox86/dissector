require 'rubygems'
require 'bundler'
Bundler.require(:default)

require 'color_chooser'
require 'generate'
require 'listbox'
require 'packet'
require 'packets'
require 'structure'

require 'ncurses'

def do_preview(y, x, value)
  if(@states[value].nil?)
    if(@same_structure)
      state = Packet.new(@packets.get_data(value), @structure_common)
    else
      state = Packet.new(@packets.get_data(value), @packets.get_direction(value) == Packets::CLIENT_TO_SERVER ? @structure_outgoing : @structure_incoming)
    end
    @states[value] = state
  end
  state = @states[value]

  window = HexWindow.new(y, x, @packets.get_data(value), true)
  window.draw()
end

def do_go(value = nil)
  @generate = @generate || Generate.new()
  if(@same_structure)
    @generate.go(@structure_common, @structure_common)
  else
    @generate.go(@structure_incoming, @structure_outgoing)
  end
end

if(ARGV.size() < 1)
  puts("Usage: main.rb <pcap file> [capture filter]")
  exit(1)
end

@packets = Packets.new(ARGV[0], ARGV[1, ARGV.length].join(' '))
@packet_list = @packets.get_list
if(@packet_list.nil?)
  puts("Couldn't load the packet list!")
  exit(1)
end

if(@packet_list.length == 0)
  puts("Couldn't load any packets")
  exit(1)
end

begin
  Ncurses.initscr

  Ncurses.cbreak
  Ncurses.noecho
  Ncurses.curs_set(0)
  Ncurses.keypad(Ncurses.stdscr, true)

  # Set a couple of constants that are missing from Ncurses (these may run into portability issues..)
  Ncurses::KEY_ESCAPE = 27
  Ncurses::KEY_TAB    = ?\t

  ColorChooser.initialize()

  window = Ncurses.stdscr


  @structure_incoming = Structure.new()
  @structure_outgoing = Structure.new()
  @structure_common   = Structure.new()
  begin
    File.open(ARGV[0] + '.save', "rb") do |f|
      @structure_incoming, @structure_outgoing, @structure_common, @generate, @same_structure, ColorChooser.color = Marshal.load(f)
    end
  rescue Exception
  end
  ColorChooser.color = ColorChooser.color || 0

  if(@same_structure.nil?)
    @same_structure = Listbox.new(0, {false=>"Yes", true=>"No"}).prompt("Do you want to use separate structures for incoming/outgoing packets?")
  end

  list = Listbox.new(0, @packet_list, false, 20)
  list.add_preview_callback(method(:do_preview))
  list.add_key_callback(?g, method(:do_go))

  @states = []
  loop do
    index = list.prompt("Choose a packet to continue...")
    if(index.nil?)
      exit
    end

    if(@states[index].nil?)
      if(@same_structure)
        state = Packet.new(@packets.get_data(index), @structure_common)
      else
        state = Packet.new(@packets.get_data(index), @packets.get_direction(index) == Packets::CLIENT_TO_SERVER ? @structure_outgoing : @structure_incoming)
      end
      @states[index] = state
    end
    state = @states[index]

    state.go()

    # Save the current states
    File.open(ARGV[0] + '.save', "wb") do |f|
      Marshal.dump([@structure_incoming, @structure_outgoing, @structure_common, @generate, @same_structure, ColorChooser.color], f)
    end

  end

ensure
  Ncurses.endwin
  puts("Bye!")
end

