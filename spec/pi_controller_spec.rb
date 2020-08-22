require './controller/pi_controller'

get_pin = nil

RSpec.describe PiController do
  before(:each) do
    @gpioLib = double("rpi_gpio")
    allow(@gpioLib).to receive(:reset)
    allow(@gpioLib).to receive(:setup)
    allow(@gpioLib).to receive(:set_numbering)
    @controller = PiController.new(@gpioLib)
    get_pin = proc { |pin| @controller.instance_variable_get(pin) }
  end

  describe ".initialize" do
    it "should call gpio setup at initialize" do
      controller = PiController.allocate
      expect(controller).to receive(:set_gpio)
      controller.send(:initialize, @gpioLib)
    end

    it "should reset numbering schema to :board" do
      expect(@gpioLib).to receive(:reset)
      expect(@gpioLib).to receive(:set_numbering).with(:board)
      @controller.set_gpio
    end

    it "should set output pins" do
      [:@PIN_LED_RED, :@PIN_LED_GREEN, :@PIN_LED_BLUE, :@PIN_LED_YELLOW,
        :@PIN_LOCK].each { |p|
          expect(@gpioLib).to receive(:setup)
           .with(get_pin.call(p), :as => :output)
      }
      @controller.set_gpio
    end

    it "should set input pins" do
      [:@PIN_DOOR, :@PIN_BTN].each { |p| 
	expect(@gpioLib).to receive(:setup)
          .with(get_pin.call(p), :as => :input)
      }
      @controller.set_gpio
    end
  end
  describe "gpio wrapper methods" do
    it "should have a method for turning on an led" do
      [:@PIN_LED_RED, :@PIN_LED_GREEN, :@PIN_LED_BLUE].each do |led|
        expect(@gpioLib).to receive(:set_low).with(get_pin.call led)
      end
      expect(@gpioLib).to receive(:set_high).with(get_pin.call :@PIN_LED_YELLOW)
      @controller.set_led get_pin.call(:@PIN_LED_YELLOW)
    end

    it "should have a method to check the lock and closed status" do
      [[:locked?, :@PIN_LOCK], [:closed?, :@PIN_DOOR]].each do |k|
        expect(@gpioLib).to receive(:high?)
         .with(get_pin.call k[1])
           .and_return(false)
        expect(@controller.send k[0]).to be false
        expect(@gpioLib).to receive(:high?)
         .with(get_pin.call k[1])
           .and_return(true)
        expect(@controller.send k[0]).to be true
      end
    end

  end

  describe ".lock!" do
   it "should ignore lock command if the door is already locked" do
     expect(@controller).to receive(:locked?).and_return(true)
     expect(@gpioLib).not_to receive(:set_high)
        .with(get_pin.call(:@PIN_LOCK))
     @controller.lock!
   end

   it "should ignore lock command if the door is open" do
     expect(@controller).to receive(:locked?).and_return(false)
     expect(@controller).to receive(:closed?).and_return(false)
     expect(@gpioLib).not_to receive(:set_high)
        .with(get_pin.call(:@PIN_LOCK))
     @controller.lock!
   end

   it "should lock the door and turn on the blue light" do
     expect(@controller).to receive(:locked?).and_return(false)
     expect(@controller).to receive(:closed?).and_return(true)
     expect(@gpioLib).to receive(:set_high)
        .with(get_pin.call(:@PIN_LOCK))
     expect(@controller).to receive(:set_led)
        .with(get_pin.call(:@PIN_LED_BLUE))
     @controller.lock!     
   end
  end

  describe ".unlock!" do
   it "should unlock the door and turn on the green light" do
     expect(@gpioLib).to receive(:set_low)
        .with(get_pin.call(:@PIN_LOCK))
     expect(@controller).to receive(:set_led)
        .with(get_pin.call(:@PIN_LED_GREEN))
     @controller.unlock!     
   end
   it "should call unlock when button is pressed" do
     allow(@gpioLib).to receive(:watch)
     expect(@gpioLib).to receive(:watch)
       .with(get_pin.call(:@PIN_BTN), :on => :rising) do |&block|
          expect(@controller).to receive(:unlock!)
          block.call
       end
     @controller.set_callbacks 
   end
   it "should call lock when door is closed" do
     allow(@gpioLib).to receive(:watch)
     expect(@gpioLib).to receive(:watch)
       .with(get_pin.call(:@PIN_DOOR), :on => :both) do |&block|
          expect(@controller).to receive(:door_status).with(1)
          block.call(2,1)
       end
     @controller.set_callbacks 
   end
  end
  describe ".door_status" do
    it "should synchronize on the mutex" do
      expect(get_pin.call(:@mutex)).to receive(:synchronize).with(no_args)
      @controller.door_status 1
    end
    describe "synchronized block" do
      before(:each) do
        allow(Kernel).to receive(:sleep)
      end 

      def set_door(ctrl, value)
        allow(ctrl.instance_variable_get(:@mutex)).to receive(:synchronize)
            .with(no_args) do |&sync|
               sync.call
             end
        ctrl.door_status value
      end

      it "should exit thread if it is alive" do
        thread = get_pin.call(:@thread)
        expect(thread).to receive(:alive?).and_return(true)
        expect(thread).to receive(:exit)
        expect(Thread).to_not receive(:new)
        set_door(@controller, 0) 
      end

      it "should creae a thread when door closes that locks the door" do
        thread = get_pin.call(:@thread)
        expect(thread).to receive(:alive?).and_return(false)
        expect(thread).to_not receive(:exit)
        expect(Thread).to receive(:new).with(no_args) do |&worker|
	   expect_any_instance_of(Kernel).to receive(:sleep).with(2)
           expect(@controller).to receive(:lock!)
           worker.call
        end
        set_door(@controller, 1) 
        
#        expect(@controller).to receive(:lock!)
#        expect(Thread).to receive(:new).with(no_args) do |&worker|
#          worker.call
#        end
#        call_block(@controller, 1) do |sync|
#          sync.call
#        end
      end
    end
  end
end
