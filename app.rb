require './controller/pi_controller'
require 'rpi_gpio'

controller = PiController.new RPi::GPIO
controller.set_led(0)
pass = "initial"
expected = "1234"
retries = 0
while pass != "stop" do
   pass = gets.chomp
   if pass == expected
	controller.unlock!
	retries = 0
        expected = "1234"
   else
       retries += 1
       controller.set_yellow
       if retries > 3
          controller.set_red
	  expected = "faisal"
       end
   end 
end
controller.cleanup

