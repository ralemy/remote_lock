require "./controller/web_controller"

RSpec.describe WebController do
  before(:each) do
    @controller = WebController.new('someUrl', 'someUser', 'somePass')
  end
  describe "initialize" do
    it "should inject url, admin user and password" do
      expect(@controller.instance_variable_get :@baseUrl).to eq('someUrl')
      expect(@controller.instance_variable_get :@user).to eq('someUser')
      expect(@controller.instance_variable_get :@pass).to eq('somePass')
    end
  end

end