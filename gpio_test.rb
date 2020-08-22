require 'rpi_gpio'
RPi::GPIO.set_numbering :board
RPi::GPIO.setup 8, :as => :output
RPi::GPIO.setup 18, :as => :input

mutex = Mutex.new
thread = Thread.new {}

RPi::GPIO.watch 18, :on => :both do |pin, value| 
  mutex.synchronize do
    thread.exit if thread.alive?
    thread = Thread.new do
      sleep 2
      puts "final state: #{value}"
    end 
  end
  puts "#{pin}: #{value} / #{RPi::GPIO.high? 18}" 
end

RPi::GPIO.set_high 8
puts "Pin high"
puts (`numlockx status`.include? 'on' ? "Numlock is on" : "Numlock is off")
puts `numlockx on`
gets.chomp
puts "Pin 8 is #{RPi::GPIO.high? 8}"
RPi::GPIO.set_low 8
puts "Pin 8 is #{RPi::GPIO.high? 8}"
RPi::GPIO.reset


