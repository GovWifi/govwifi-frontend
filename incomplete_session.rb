#This starts an EAP-PEAP session, but does not complete it, resulting in a hanging session in Freeradius
# for testing purposes only

require "socket"

def reserve_session
  packet = "01 00 00 84 14 53 e1 f2 1e 78 41 8a b6 e3 a4 aa bd 81 06 a3 01 0b 61 6e 6f 6e 79 6d 6f 75 73 04 06 7f 00 00 01 1f 13 30 32 2d 30 30 2d 30 30 2d 30 30 2d 30 30 2d 30 31 0c 06 00 00 05 78 3d 06 00 00 00 13 06 06 00 00 00 02 4d 18 43 4f 4e 4e 45 43 54 20 31 31 4d 62 70 73 20 38 30 32 2e 31 31 62 4f 10 02 bd 00 0e 01 61 6e 6f 6e 79 6d 6f 75 73 50 12 52 95 f3 ed f8 72 55 55 75 2c e0 7c cd 91 67 95"
  elements = packet.split(" ").map{|element| Integer("0x#{element}")}
  UDPSocket.new.send(elements.pack('C*'), 0, "127.0.0.1", 1812)
end
