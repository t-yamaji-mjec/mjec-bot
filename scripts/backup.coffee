# Description:
#   バックアップ・リストア機能(非公開).
#
# Notes:
#   定期と手動で実行するバックアップとその内容でリストアする.
#
# Commands:
#  バックアップ - 手動バックアップを作成する
#  リストア [定期 or 手動] - 定期：定期保存ファイルからリストアする、手動：バックアップコマンドで保存したファイルからリストアする
#
CosDA = require('./_cos_data_access')
cronJob = require('cron').CronJob
Bucket = process.env['BUCKET_NAME']
module.exports = (robot) ->

  new cronJob('0 00 22 * * 1-5', () ->
    #平日の22時にバックアップを実行
    backup(robot, "regular")
  ).start()

  robot.respond /バックアップ/i, (msg) ->
    backup(msg, "manual")

  robot.respond /リストア (定期|手動)/i, (msg) ->
    mode = if msg.match[1] is "定期" then "regular" else "manual"
    restore(msg, mode)

  backup = (msg, mode) ->
    fileList = CosDA.doListObjects(Bucket)  #Promiseを返却
    fileList.then((list) -> backupLogic msg,  mode, list).catch(
                  (e) -> console.log e)

  backupLogic = (msg, mode, fileList) ->
    if fileList isnt null and fileList.Contents isnt null
      for content in fileList.Contents when /^data\/*/.test(content.Key) and content.Size isnt 0
        backupPath = content.Key.replace(/^data/, "backup_#{mode}")
        CosDA.doCopyObject(Bucket, "#{Bucket}/#{content.Key}", backupPath);
    if msg.message?.user?.room?
      msg.send "#{mode}のバックアップを実行しました。"

  restore = (msg, mode) ->
    fileList = CosDA.doListObjects(Bucket)  #Promiseを返却
    fileList.then((list) -> restoreLogic msg, mode, list).catch(
                  (e) -> console.log e)

  restoreLogic = (msg, mode, fileList) ->
    if fileList isnt null and fileList.Contents isnt null
      regexp1 = new RegExp("^backup_#{mode}\/.*")
      regexp2 = new RegExp("^backup_#{mode}")
      for content in fileList.Contents when regexp1.test(content.Key) and content.Size isnt 0
        restorePath = content.Key.replace(regexp2, "data")
        CosDA.doCopyObject(Bucket, "#{Bucket}/#{content.Key}", restorePath);
    msg.send "#{mode}からリストアを実行しました。"
