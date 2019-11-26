# Description:
#   コンテンツダウンロード機能.
#
# Notes:
#   定期と手動で実行するバックアップとその内容でリストアする.
#
# Commands:
#  コンテンツリスト - 特定フォルダにあるファイルの一覧(No)を表示する
#  コンテンツ [No] - 選択したファイルをSlack上に添付する
#
CosDA = require('./_cos_data_access')
Bucket = process.env['BUCKET_NAME']
module.exports = (robot) ->

  robot.hear /コンテンツリスト/i, (msg) ->
    getContents(msg, "list")

  robot.hear /コンテンツ (\d+)/i, (msg) ->
    getContents(msg, "download")

  getContents = (msg, mode) ->
    fileList = CosDA.doListObjects(Bucket)  #Promiseを返却
    fileList.then((list) -> if mode is "list" then getContentsList msg, list else getContentsFile msg, list).catch(
                  (e) -> console.log e)

  getContentsList = (msg, fileList) ->
    if fileList isnt null and fileList.Contents isnt null
      regexp1 = new RegExp("^contents\/.*")
      regexp2 = new RegExp("^contents\/")
      message = "【ダウンロードコンテンツ一覧】\n"
      outputNo = 0
      for content in fileList.Contents when regexp1.test(content.Key) and content.Size isnt 0
        fileName = content.Key.replace(regexp2, "")
        outputNo += 1
        message += "[#{outputNo}] #{fileName}\n"
      msg.send message

  getContentsFile = (msg, fileList) ->
    if fileList isnt null and fileList.Contents isnt null
      selectNo = msg.match[1]
      regexp1 = new RegExp("^contents\/.*")
      outputNo = 0
      for content in fileList.Contents when regexp1.test(content.Key) and content.Size isnt 0
        outputNo += 1
        filePath = if outputNo is selectNo then content.Key
      filePromise = CosDA.doGetObject(Bucket, filePath ? "")
      filePromise.then((data) -> getContentsAttached msg, data).catch(
                       (e) -> console.log e)

  getContentsAttached = (msg, data) ->
    msg.send data
