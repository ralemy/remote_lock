require './controller/pi_controller'

RSpec.describe PiController do
  before(:each) do
    @gpio = double("rpi_gpio")
    allow(@gpio).to receive(:reset)
    allow(@gpio).to receive(:setup)
    allow(@gpio).to receive(:set_numbering)
    allow(@gpio).to receive(:watch)
    @controller = PiController.new(@gpio)
  end

  describe ".initialize" do
    it "should call gpio setup at initialize" do
      controller = PiController.allocate
      expect(controller).to receive(:set_gpio)
      expect(@controller.instance_variable_get(:@mutex)).to be_a(Mutex)
      expect(@controller.instance_variable_get(:@thread)).to be_a(Thread)
      controller.send(:initialize, @gpio)
    end
  end

  describe ".set_gpio" do
    it "should reset numbering schema to :board" do
      expect(@gpio).to receive(:reset)
      expect(@gpio).to receive(:set_numbering).with(:board)
      @controller.set_gpio
    end

    it "should set output pins" do
      [PiController::RED_PIN, PiController::GREEN_PIN, PiController::BLUE_PIN,
       PiController::YELLOW_PIN, PiController::LOCK_PIN].each { |p|
        expect(@gpio).to receive(:setup).with(p, :as => :output)
      }
      @controller.set_gpio
    end

    it "should set input pins" do
      [PiController::DOOR_PIN, PiController::BTN_PIN].each { |p|
        expect(@gpio).to receive(:setup).with(p, :as => :input)
      }
      @controller.set_gpio
    end

    it "should set call backs for pins" do
      expect(@controller).to receive(:set_callbacks)
      @controller.set_gpio
    end
  end

  describe ".set_callbacks" do
    it "should call unlock when button is pressed" do
      allow(@gpio).to receive(:watch)
      expect(@gpio).to receive(:watch).with(PiController::BTN_PIN, :on => :rising) do |&block|
        expect(@controller).to receive(:unlock!)
        block.call
      end
      @controller.set_callbacks
    end
    it "should call lock when door is closed" do
      allow(@gpio).to receive(:watch)
      expect(@gpio).to receive(:watch).with(PiController::DOOR_PIN, :on => :both) do |&block|
        expect(@controller).to receive(:door_status).with(1)
        block.call(2, 1)
      end
      @controller.set_callbacks
    end
  end
  
  describe "gpio wrapper methods" do
    it "should have a method for turning on an led" do
      [PiController::RED_PIN, PiController::GREEN_PIN, PiController::BLUE_PIN].each do |led|
        expect(@gpio).to receive(:set_low).with(led)
      end
      expect(@gpio).to receive(:set_high).with(PiController::YELLOW_PIN)
      @controller.set_led(PiController::YELLOW_PIN)
    end

    it "should have a method to check the lock and closed status" do
      [[:locked?, PiController::LOCK_PIN], [:closed?, PiController::DOOR_PIN]].each do |k|
        expect(@gpio).to receive(:high?).with(k[1]).and_return(false)
        expect(@controller.send k[0]).to be false
        expect(@gpio).to receive(:high?).with(k[1]).and_return(true)
        expect(@controller.send k[0]).to be true
      end
    end

    it "should have a method to turn on the red led" do
      expect(@controller).to receive(:set_led).with(PiController::RED_PIN)
      @controller.set_red
    end

    it "should have a method to turn on the yellow led" do
      expect(@controller).to receive(:set_led).with(PiController::YELLOW_PIN)
      @controller.set_yellow
    end
  end

  describe ".lock!" do
    it "should ignore lock command if the door is already locked" do
      expect(@controller).to receive(:locked?).and_return(true)
      expect(@gpio).not_to receive(:set_high).with(PiController::LOCK_PIN)
      @controller.lock!
    end

    it "should ignore lock command if the door is open" do
      expect(@controller).to receive(:locked?).and_return(false)
      expect(@controller).to receive(:closed?).and_return(false)
      expect(@gpio).not_to receive(:set_high).with(PiController::LOCK_PIN)
      @controller.lock!
    end

    it "should lock the door and turn on the blue light" do
      expect(@controller).to receive(:locked?).and_return(false)
      expect(@controller).to receive(:closed?).and_return(true)
      expect(@gpio).to receive(:set_high).with(PiController::LOCK_PIN)
      expect(@controller).to receive(:set_led).with(PiController::BLUE_PIN)
      @controller.lock!
    end
  end

  describe ".unlock!" do
    it "should unlock the door and turn on the green light" do
      expect(@gpio).to receive(:set_low).with(PiController::LOCK_PIN)
      expect(@controller).to receive(:set_led).with(PiController::GREEN_PIN)
      @controller.unlock!
    end
  end

  describe ".door_status" do
    it "should synchronize on the mutex" do
      expect(@controller.instance_variable_get(:@mutex)).to receive(:synchronize).with(no_args)
      @controller.door_status 1
    end

    describe "synchronized block" do

      def set_door(ctrl, value)
        allow(ctrl.instance_variable_get(:@mutex)).to receive(:synchronize)
                                                          .with(no_args) do |&sync|
          sync.call
        end
        ctrl.door_status value
      end

      it "should exit thread if it is alive" do
        thread = @controller.instance_variable_get(:@thread)
        expect(thread).to receive(:alive?).and_return(true)
        expect(thread).to receive(:exit)
        expect(Thread).to_not receive(:new)
        set_door(@controller, 0)
      end

      it "should creae a thread when door closes that locks the door" do
        thread = @controller.instance_variable_get(:@thread)
        expect(thread).to receive(:alive?).and_return(false)
        expect(thread).to_not receive(:exit)
        expect(Thread).to receive(:new).with(no_args) do |&worker|
          expect_any_instance_of(Kernel).to receive(:sleep).with(2)
          expect(@controller).to receive(:lock!)
          worker.call
        end
        set_door(@controller, 1)
      end
    end
  end

  describe ".cleanup" do
    it "should exit thread if still alive" do
      thread = @controller.instance_variable_get(:@thread)
      expect(thread).to receive(:alive?).and_return(true)
      expect(thread).to receive(:exit)
      expect(@gpio).to receive(:reset)
      @controller.cleanup
    end
  end
end
