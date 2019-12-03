# Description:
#   Catme is the most important thing in life
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   hubot cat me - Receive a cat
module.exports = (robot) ->
  robot.respond /cat me/i, (msg) ->
    request = require("request")
    request.get
     url: 'https://thecatapi.com/api/images/get?format=html'
    , (err, res) ->
      msg.send /src="(.*)">/.exec(res.body)[1]
