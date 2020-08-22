
class PiController
  LED_PINS = [
      RED_PIN = 7, GREEN_PIN = 11, BLUE_PIN = 13, YELLOW_PIN=15,
      LOCK_PIN=16, BTN_PIN=18, DOOR_PIN = 22]

  def initialize(gpio)
    @gpio = gpio
    @mutex = Mutex.new
    @thread = Thread.new {}
    set_gpio
  end

  def set_gpio
    @gpio.reset
    @gpio.set_numbering :board
    [RED_PIN, GREEN_PIN, BLUE_PIN, YELLOW_PIN, LOCK_PIN]
        .each { |p| @gpio.setup p, :as => :output }
    [DOOR_PIN, BTN_PIN].each { |p| @gpio.setup p, :as => :input }
    set_callbacks
  end

  def set_callbacks
    controller = self
    @gpio.watch BTN_PIN, :on => :rising do |_, value|
      controller.unlock!
    end
    @gpio.watch DOOR_PIN, :on => :both do |_, value|
      controller.door_status value
    end
  end

  def door_status(value)
    controller = self
    @mutex.synchronize do
      @thread.exit if @thread.alive?
      return if value == 0
      @thread = Thread.new do
        sleep 2
        controller.lock!
      end
    end
  end

  def set_led(led)
    [RED_PIN, BLUE_PIN, GREEN_PIN, YELLOW_PIN].each do |l|
      @gpio.send(l == led ? :set_high : :set_low, l)
    end
  end

  def locked?
    @gpio.high? LOCK_PIN
  end

  def closed?
    @gpio.high? DOOR_PIN
  end

  def lock!
    return if locked?
    return unless closed?
    @gpio.set_high LOCK_PIN
    set_led BLUE_PIN
  end

  def unlock!
    @gpio.set_low LOCK_PIN
    set_led GREEN_PIN
  end

  def cleanup
    @thread.exit if @thread.alive?
    @gpio.reset
  end

  def set_red
    set_led(RED_PIN)
  end

  def set_yellow
    set_led(YELLOW_PIN)
  end
end
