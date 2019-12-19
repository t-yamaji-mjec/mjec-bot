# Description:
#   画像検索機能
#
# Notes:
#   Pixabay APIを呼び出して画像を検索する.
#
# Commands:
#   画像検索 [名詞] - 画像をランダム検索する
#   画像検索N [名詞] - 画像を検索する(未編集)
#
module.exports = (robot) ->
  robot.hear /画像検索\s(.*)/i, (msg) ->
    searchImage(msg, "random")

  robot.hear /画像検索N\s(.*)/i, (msg) ->
    searchImage(msg, "normal")

  searchImage = (msg, mode) ->
    request = require("request")
    apiKey = '' + process.env['PIXABAY_API_KEY']
    keyword = '&q=' + encodeURIComponent(msg.match[1]);
    option = '&lang=ja&safesearch=true&per_page=20';

    request.get
     url: "https://pixabay.com/api/?key=#{apiKey}#{keyword}#{option}"
    , (err, res) ->
      #console.log res.body
      json = JSON.parse(res.body)

      if mode is "random"
        rndIndex = createRandomNumber json.hits.length
        msg.send json.hits[rndIndex].largeImageURL
      if mode is "normal"
        msg.send json.hits[0].largeImageURL

  createRandomNumber = (maxNumber) ->
    Math.floor(Math.random() * maxNumber) #0 ～ (maxNumber-1)を生成
