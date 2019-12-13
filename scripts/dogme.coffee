# Description:
#   犬画像を表示(非公開機能)
#
# Commands:
#   dog me - 犬画像を表示
#
module.exports = (robot) ->
  robot.respond /dog me/i, (msg) ->
    request = require("request")
    request.get
     url: 'https://dog.ceo/api/breeds/image/random'
    , (err, res) ->
      json = JSON.parse(res.body)
      msg.send json.message
