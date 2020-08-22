class PiController
  def initialize(gpioLib)
    @gpioLib = gpioLib
    @mutex = Mutex.new
    @thread = Thread.new {}
    set_gpio
  end  

  def set_gpio
    @gpioLib.reset
    @gpioLib.set_numbering :board

    @PIN_LED_RED = 7
    @PIN_LED_GREEN = 11
    @PIN_LED_BLUE = 13
    @PIN_LED_YELLOW = 15
    @PIN_BTN = 18
    @PIN_LOCK = 16
    @PIN_DOOR = 22

    [@PIN_LED_RED, @PIN_LED_GREEN, @PIN_LED_BLUE, @PIN_LED_YELLOW,
      @PIN_LOCK].each { |p| @gpioLib.setup p, :as => :output }
    [@PIN_DOOR,  @PIN_BTN].each { |p| @gpioLib.setup p, :as => :input }
    set_callbacks
  end

  def set_callbacks
    controller = self
    @gpioLib.watch @PIN_BTN, :on => :rising do |pin, value|
      puts "btn clicked" 
      controller.unlock!
    end
    @gpioLib.watch @PIN_DOOR, :on => :both do |pin, value|
      puts (value == 0 ? "door opened" : "door closed")
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
    [@PIN_LED_RED, @PIN_LED_GREEN, @PIN_LED_BLUE, @PIN_LED_YELLOW].each do |l|
      @gpioLib.send(l == led ? :set_high : :set_low, l)
    end
  end

  def locked?
    return @gpioLib.high? @PIN_LOCK
  end

  def closed?
    return @gpioLib.high? @PIN_DOOR
  end

  def lock!
    return if locked?
    return unless closed?
    @gpioLib.set_high @PIN_LOCK
    set_led @PIN_LED_BLUE
  end

  def unlock!
    @gpioLib.set_low @PIN_LOCK
    set_led @PIN_LED_GREEN
  end

  def cleanup
    @thread.exit if @thread.alive?
    @gpioLib.reset
  end
 
  def set_red
    set_led(@PIN_LED_RED)
  end

  def set_yellow
    set_led(@PIN_LED_YELLOW)
  end
 end
