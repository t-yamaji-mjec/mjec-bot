# Description:
#   TODO機能
#
# Notes:
#   ユーザー毎に作業状況を記録して、一覧出力ができる機能
#
# Commands:
#  作業開始 [作業名] - 新しく開始した作業を記録する
#  作業開始 [番号] [作業名] - 指定した作業名を修正する
#  作業終了 [番号] - 指定した作業を終了する
#  作業削除 [番号] - 指定した作業を削除する
#  作業一覧 - 当日の作業一覧を出力する
#  作業一覧 [YYYY/MM/DD] - 指定した日付の作業一覧を出力する
#  作業管理 - チャンネル内の未終了作業を一覧出力する
#
CosDA = require('./_cos_data_access')
strEnpty = "空欄"
module.exports = (robot) ->

  robot.hear /作業開始\s(.*)$/i, (msg) ->
    todo(msg, "start")
  robot.hear /作業終了\s(\d)$/i, (msg) ->
    todo(msg, "end")
  robot.hear /作業中断\s(\d)$/i, (msg) ->
    todo(msg, "suspend")
  robot.hear /作業削除\s(\d)$/i, (msg) ->
    todo(msg, "delete")
  robot.hear /作業一覧$/i, (msg) ->
    todo(msg, "record_now")
  robot.hear /作業一覧\s(\d+\D+\d+\D+\d+)$/i, (msg) ->
    todo(msg, "record")
  robot.hear /作業管理$/i, (msg) ->
    manage(msg)

#[日付処理用ライブラリ]-----------------------------------------------------------
  getNowDateTime = ->
    d = new Date
    d.setTime((d.getTime() + 1000*60*60*9)) #JSTに変換
    year = d.getFullYear()   # 年（西暦）
    month = d.getMonth() + 1 # 月
    day = d.getDate()        # 日
    hour = d.getHours()      # 時
    min = d.getMinutes()     # 分
    return outputDateTime(year, month, day, hour, min)

  outputDateTime = (year, month, day, hour, min) ->
    return "#{year}/#{month}/#{day} #{hour}:#{min}"

  getOutputDateTime = (strDate) ->
    arr = strDate.split(/\//)
    outputDate(arr[0], (" " + arr[1]).slice(-2), (" " + arr[2]).slice(-2))

  getOutputTime = (strTime) ->
    if strTime is "" then return "     "
    arr = strTime.split(/:/)
    outputTime((" " + arr[0]).slice(-2), ("0" + arr[1]).slice(-2))

  getDateString = (date) -> /^(\d+\D+\d+\D+\d+)/.exec(date)[0]

  getDate = (date) -> return (new Date(getDateString(date))).getTime()

  tryGetDate = (date, defult) ->
    try
      dateStr = /^(\d+\D+\d+\D+\d+)/.exec(date)[0]
      return (new Date(dateStr)).getTime()
    catch
      return defult

  setNextDate = (date) -> date + (24 * 60 * 60 * 1000)
#-------------------------------------------------------------------------------

#[ファイルIO用ライブラリ]---------------------------------------------------------
  createTodoPath = (userId) ->
    "data/todo_#{userId}.json"

  jsonFileRead = (data) ->
    JSON.parse(Buffer.from(data.Body).toString()) if data isnt null

  jsonFileWrite = (bucket, path, json) ->
    CosDA.doCreateObject(bucket, path, JSON.stringify(json))
#-------------------------------------------------------------------------------
  createNewTodo = (userId, userName, sequence, taskName, stratDateTime) ->
    json = getTodoBase()
    json["UserId"] = userId
    json["UserName"] = userName
    json["Sequence"] = sequence
    json["TaskName"] = taskName
    json["Suspend"] = 0
    json["StratDateTime"] = stratDateTime
    json["EndDateTime"] = ""
    console.log json
    return json

  getTodoBase = ->
    try
      JSON.parse('{"UserId":"","UserName":"","Sequence":"","TaskName":"","Suspend":"","StratDateTime":"","EndDateTime":""}')
    catch e
      console.log e

  todo = (msg, mode) ->
    path = require('path')
    userId = '' + msg.message.user.id #文字列に変換
    bucket = process.env['BUCKET_NAME']
    userData = CosDA.doGetObject(bucket, createTodoPath(userId)) #Promiseを返却
    userData.then((data) -> todoLogic msg, bucket, userId, mode, jsonFileRead(data)).catch(
                  (e) -> todoLogic msg, bucket, userId, mode, JSON.parse("[]"))

  todoLogic = (msg, bucket, userId, mode, userDataJson) ->
    #console.log userDataJson
    userName = '' + msg.message.user.name #文字列に変換
    nowDateTime = getNowDateTime()
    if userDataJson.length > 1 then userDataJson.sort sortdate

    #引数に連番を使う場合は作業名を取得する
    if mode == "end" or mode == "suspend" or mode == "delete"
      sequence = Number(msg.match[1])
      taskName = getTaskName(userDataJson, userId, sequence)
      if taskName is null
        return sendMassege(msg, "#{sequence}に該当する作業は存在しません。")

    #作業一覧の場合、中断または対象日に発生している作業の一覧を出力する
    if mode == "record" or mode == "record_now"
      if mode is "record_now"
        judgeDate = getDate(nowDateTime)
        outputDate = getDateString(nowDateTime)
      else
        judgeDate = tryGetDate(msg.match[1], getDateString(nowDateTime))
        outputDate = msg.match[1]
      for json in userDataJson when json.UserId is userId
        if json.Suspend is 1 then json.EndDateTime = "中断"
      massege = "```#{userName}さんの作業一覧(#{outputDate})\n"
      massege += "(#{json.Sequence}) #{json.TaskName} [#{json.StratDateTime}] ～ [#{json.EndDateTime}]\n" for json in userDataJson when json.UserId is userId and
        getDate(json.StratDateTime) < setNextDate(judgeDate) and
        tryGetDate(json.EndDateTime, judgeDate) >= judgeDate
      massege += "```"
      return sendMassege(msg, massege)
    #作業開始の場合、新しい作業を登録する
    else if mode == "start"
      taskName = msg.match[1]
      newSequence = getNewSequence(userDataJson, userId)
      userDataJson.push(createNewTodo(userId, userName, newSequence, taskName, nowDateTime))
      jsonFileWrite(bucket, createTodoPath(userId), userDataJson)
      return sendMassege(msg, "#{userName}さん (#{newSequence})に #{taskName} を登録しました")
    #作業終了の場合、該当作業に終了日時を入れる
    else if mode == "end"
      outputDataJson = updTask(userDataJson, userId, sequence, 0, nowDateTime)
      jsonFileWrite(bucket, createTodoPath(userId), outputDataJson)
      return sendMassege(msg, "#{userName}さん #{taskName} が終了しました")
    #作業中断の場合、該当作業に中断フラグを入れる
    else if mode == "suspend"
      outputDataJson = updTask(userDataJson, userId, sequence, 1, "")
      jsonFileWrite(bucket, createTodoPath(userId), outputDataJson)
      return sendMassege(msg, "#{userName}さん #{taskName} を中断しました")
    #作業削除の場合、該当作業を削除
    else if mode == "delete"
      outputDataJson = delTask(userDataJson, userId, sequence)
      jsonFileWrite(bucket, createTodoPath(userId), outputDataJson)
      return sendMassege(msg, "#{userName}さん #{taskName} を削除しました")
    #console.log outputDataJson

  sendMassege = (msg, massege) -> msg.send massege

  addTask = (userDataJson, userId, userName, taskName, startDateTime) ->
    userDataJson.push(createNewTodo(userId, userName, taskName, startDateTime))

  updTask = (userDataJson, userId, sequence, suspend, endDateTime) ->
    for json in userDataJson when json.UserId == userId and json.Sequence == sequence
      if endDateTime isnt "" then json.EndDateTime = endDateTime
      json.Suspend = suspend
    return userDataJson

  delTask = (userDataJson, userId, sequence) ->
    newUserData = userDataJson.filter (item, index) ->
      if item.UserId == userId and item.Sequence != sequence then return true
    return newUserData

  sortdate = (a, b) -> a.Sequence - b.Sequence

  getNewSequence = (userDataJson, userId) ->
    maxSequence = 0
    for json in userDataJson when json.UserId == userId
      #console.log "Sequence:#{json.Sequence}"
      if maxSequence < json.Sequence then maxSequence = json.Sequence
    return maxSequence + 1

  getTaskName = (userDataJson, userId, sequence) ->
    for json in userDataJson when json.UserId == userId and json.Sequence == sequence
      return json.TaskName
    return null
