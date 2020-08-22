require "faraday"

class WebController
  SERVER_RESPONSES = [GOOD_PASS = 200, BAD_PASS = 404, LOCKED_OUT = 401, UNLOCK = 202]

  def initialize(baseUrl, user, pass)
    @baseUrl = baseUrl
    @user = user
    @pass = pass
  end

  def checkPassword(password)
    response = Faraday.get(@baseUrl + '/guest_check?guest_key=' + password)
    response.status
  end

  def checkCommand
    response = Faraday.get(@baseUrl + '/guest_command')
    response.status
  end

end