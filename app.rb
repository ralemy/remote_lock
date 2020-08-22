require './controller/pi_controller'
require './controller/web_controller'
require 'rpi_gpio'

controller = PiController.new RPi::GPIO
web = WebController.new('https://nelson-258-106.herokuapp.com', 'faisal', 'ansari')
controller.set_led(0)
pass = "initial"
command_thread = Thread.new do
  while true
    sleep 1
    controller.unlock! if web.checkCommand == WebController::UNLOCK
  end
end
while pass != "stop" do
  puts `setleds -D +num`
  pass = gets.chomp
  case web.checkPassword pass
  when WebController::GOOD_PASS
    controller.unlock!
  when WebController::BAD_PASS
    controller.set_yellow
  when WebController::LOCKED_OUT
    controller.set_red
  else
    controller.set_yellow
  end
end
command_thread.exit
controller.cleanup
