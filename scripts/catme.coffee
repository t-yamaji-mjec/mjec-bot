# Description:
#   猫を表示(非公開機能)
#
# Commands:
#   cat me - 猫を表示
#
module.exports = (robot) ->
  robot.respond /cat me/i, (msg) ->
    request = require("request")
    request.get
     url: 'https://thecatapi.com/api/images/get?format=html'
    , (err, res) ->
      msg.send /src="(.*)">/.exec(res.body)[1]
