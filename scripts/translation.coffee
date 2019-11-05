# Description:
#   翻訳機能.
#
# Notes:
#  
#  翻訳[model] [text]
#
#  (例)日→英翻訳。
#  翻訳ja-en サンプルテキスト
module.exports = (robot) ->
  request = require("request")
  robot.hear /翻訳(.*) (.*)/i, (res) -> 
    model = res.match[1]
    original = res.match[2]
    request.post
      auth:
        user: 'apikey'
        pass: process.env['TRANSLATOR_TEXT_API_KEY']
      url: 'https://gateway.watsonplatform.net/language-translator/api/v3/translate?version=2018-05-01'
      headers: 
        'Content-Type': 'application/json'
      json:
        text: original
        model_id: model 
      , (err, translation) ->
        #console.log err
        #console.log model
        #console.log original
        #console.log translation.body.translations[0].translation
        response = translation.body.translations[0].translation + " (" + original + ")" #丸括弧以降はお好みで削ってください
        res.send response
