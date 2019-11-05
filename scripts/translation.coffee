# Description:
#   翻訳機能.
#
# Notes:
#  
#  翻訳[model] [text]
#
#  (例)日→英翻訳。
#  翻訳ja-en サンプルテキスト
#
module.exports = (robot) ->
  request = require("request")
  robot.hear /翻訳[A-Za-z]{2}-[A-Za-z]{2} (.*)/i, (res) -> 
    #console.log res
    model = /[A-Za-z]{2}-[A-Za-z]{2}/.exec(res.match.input)[0]
    original = res.match[1]
    #console.log 'model:' + model
    #console.log 'original:' + original
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
        response = "原文：#{original}\n翻訳：#{translation.body.translations[0].translation}"
        res.send response
