# Description:
#   画像検索機能
#
# Commands:
#   画像検索 [名詞] - Pixabay APIを呼び出して画像を検索する
#
module.exports = (robot) ->
  robot.hear /画像検索\s(.*)/i, (msg) ->
    request = require("request")
    apiKey = '' + process.env['PIXABAY_API_KEY']
    keyword = '&q=' + encodeURIComponent(msg.match[1]);
    option = '&lang=ja&safesearch=true&per_page=20';

    request.get
     url: "https://pixabay.com/api/?key=#{apiKey}#{keyword}#{option}"
    , (err, res) ->
      #console.log res.body
      json = JSON.parse(res.body)
      msg.send json.hits[0].largeImageURL
      msg.send json.hits[1].largeImageURL
      msg.send json.hits[2].largeImageURL
