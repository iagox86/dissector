require 'hex'
require 'ncurses'
require 'pcap'

class Packets
  CLIENT_TO_SERVER = 0
  SERVER_TO_CLIENT = 1

  def initialize(filename, filter)
    @packets = []
    @index = 0
    port = nil

    inFile = Pcap::Capture.open_offline(filename)
    inFile.setfilter(filter)

    inFile.loop(-1) do |pkt|
      if(pkt.class.to_s == 'Pcap::UDPPacket')
        if(port.nil?)
          port = pkt.udp_dport
        end

        if(!pkt.udp_data.nil?)
          @packets << {
            :src => pkt.ip_src,
            :dst => pkt.ip_dst,
            :sport => pkt.udp_sport,
            :dport => pkt.udp_dport,
            :data => pkt.udp_data,
            :direction => pkt.udp_dport == port ? CLIENT_TO_SERVER : SERVER_TO_CLIENT
          }
        end
      elsif(pkt.class.to_s == 'Pcap::TCPPacket')
        if(port.nil?)
          port = pkt.tcp_dport
        end
        if(!pkt.tcp_data.nil?)
          @packets << {
            :src => pkt.ip_src,
            :dst => pkt.ip_dst,
            :sport => pkt.tcp_sport,
            :dport => pkt.tcp_dport,
            :data => pkt.tcp_data,
            :direction => pkt.tcp_dport == port ? CLIENT_TO_SERVER : SERVER_TO_CLIENT
          }
        end
      end
    end
  end

  # Get a list that's appropriate for a listbox
  def get_list
    list = []

    @packets.each do |packet|
      if(packet[:direction] == CLIENT_TO_SERVER)
        value = "%s:%s => %s:%s [%d bytes]" % [packet[:src], packet[:sport], packet[:dst], packet[:dport], packet[:data].length]
      else
        value = "%s:%s <= %s:%s [%d bytes]" % [packet[:src], packet[:sport], packet[:dst], packet[:dport], packet[:data].length]
      end

      list << value
#      list << {
#        :value => value,
#        :details => Hex.get_str(packet[:data])
#      }
              
    end

    return list
  end

  def get_details(index)
    return @packets[index]
  end

  def get_data(index)
    return @packets[index][:data]
  end

  def get_direction(index)
    return @packets[index][:direction]
  end
end

