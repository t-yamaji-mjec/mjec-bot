# Description:
#   翻訳機能.
#
# Commands:
#  翻訳リスト [言語] - modelの一覧を表示する ※言語は省略可能
#  翻訳[model] [翻訳したい文] - modelは翻訳リストのコマンドを参照
#
# Notes:
#  (例)日→英翻訳。翻訳ja-en サンプルテキスト
#
module.exports = (robot) ->
  request = require("request")

  robot.hear /翻訳リスト$/i, (msg) ->
    GetModelList(msg, "")
  robot.hear /翻訳リスト\s(.*)$/i, (msg) ->
    GetModelList(msg, msg.match[1])

  JsonFileRead = (data) ->
    JSON.parse(Buffer.from(data).toString()) if data isnt null

  GetModelList = (msg, lang) ->
    console.log lang
    CosDA = require('./_cos_data_access')
    bucket = '' + process.env['BUCKET_NAME']
    modelList = CosDA.doGetObject(bucket, "data/translation_model.json") #Promiseを返却
    modelList.then((data) -> OutputModelList msg, lang, JsonFileRead(data.Body)).catch(
                   (e) -> console.log e)

  OutputModelList = (msg, lang, modelList) ->
    massege = ''
    regexp = new RegExp("#{lang}")
    for ml in modelList
      if lang is "" or regexp.test(ml.Description) then massege += "Model：#{ml.Model}　説明：#{ml.Description}\n"
    msg.send massege

  robot.hear /翻訳[A-Za-z]{2}-[A-Za-z]{2}\s(.*)/i, (msg) ->
    model = /[A-Za-z]{2}-[A-Za-z]{2}/.exec(msg.match.input)[0]
    original = msg.match[1]
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
        response = "原文：#{original}\n翻訳：#{translation.body.translations[0].translation}"
        msg.send response
