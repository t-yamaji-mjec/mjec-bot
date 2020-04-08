# Description:
#   TODO機能
#
# Notes:
#   ユーザー毎に作業状況を記録して、一覧出力ができる機能
#
# Commands:
#  作業開始 [作業名] - 新しく開始した作業を記録する
#  作業終了 [番号] - 指定した作業を終了する
#  作業中断 [番号] - 指定した作業を中断する
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
    manage(msg, "manage")

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

  twoSlice = (data) -> (" " + data).slice(-2)

  getOutputDateTime = (strDateTime) ->
    if strDateTime is "" then return ""
    arr = strDateTime.split ' '
    dateArr = arr[0].split(/\//)
    timeArr = arr[1].split(/:/)
    return "#{dateArr[0]}/#{twoSlice(dateArr[1])}/#{twoSlice(dateArr[2])} #{twoSlice(timeArr[0])}:#{twoSlice(timeArr[1])}"

  getOutputDate = (strDate) ->
    dateArr = strDate.split(/\//)
    return "#{dateArr[0]}/#{twoSlice(dateArr[1])}/#{twoSlice(dateArr[2])}"

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

  createTodoRoomPath = (room) ->
    "data/todo_room_#{room}.json"

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
      massege = "```#{userName}さんの作業一覧(#{getOutputDate(outputDate)})\n"
      massege += "(#{json.Sequence}) #{json.TaskName}\n     [#{getOutputDateTime(json.StratDateTime)}] ～ [#{setEndDateTime(json)}]\n" for json in userDataJson when json.UserId is userId and
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
      sendMassege(msg, "#{userName}さん (#{newSequence})に #{taskName} を登録しました")
    #作業終了の場合、該当作業に終了日時を入れる
    else if mode == "end"
      outputDataJson = updTask(userDataJson, userId, sequence, 0, nowDateTime)
      jsonFileWrite(bucket, createTodoPath(userId), outputDataJson)
      sendMassege(msg, "#{userName}さん #{taskName} が終了しました")
    #作業中断の場合、該当作業に中断フラグを入れる
    else if mode == "suspend"
      outputDataJson = updTask(userDataJson, userId, sequence, 1, "")
      jsonFileWrite(bucket, createTodoPath(userId), outputDataJson)
      sendMassege(msg, "#{userName}さん #{taskName} を中断しました")
    #作業削除の場合、該当作業を削除
    else if mode == "delete"
      outputDataJson = delTask(userDataJson, userId, sequence)
      jsonFileWrite(bucket, createTodoPath(userId), outputDataJson)
      sendMassege(msg, "#{userName}さん #{taskName} を削除しました")
    #作業を更新した場合、管理用ファイルに登録する
    manage(msg,mode)
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

  setEndDateTime = (json) ->
    if json.Suspend is 1 then "中断" else getOutputDateTime(json.EndDateTime)

#[管理者機能]--------------------------------------------------------------------
  createNewManage = (userId, filePath) ->
    json = getManageBase()
    json["UserId"] = userId
    json["FilePath"] = filePath
    console.log json
    return json

  getManageBase = ->
    try
      JSON.parse('{"UserId":"","FilePath":""}')
    catch e
      console.log e

  manageDataRead = (bucket, filePath) ->
    bucket = process.env['BUCKET_NAME']
    return CosDA.doGetObject(bucket, filePath) #Promiseを返却

  manage = (msg, mode) ->
    userRoom = '' + msg.message.user.room
    bucket = process.env['BUCKET_NAME']
    manageData = CosDA.doGetObject(bucket, createTodoRoomPath(userRoom)) #Promiseを返却
    manageData.then((data) -> manageLogic msg, bucket, userRoom, mode, jsonFileRead(data)).catch(
                  (e) -> manageLogic msg, bucket, userRoom, mode, JSON.parse("[]"))

  manageLogic = (msg, bucket, userRoom, mode, manageDataJson) ->
    #作業管理の場合は、チャンネル内の未終了作業を一覧出力する
    if mode is "manage"
      dataList = []
      promiseList = []
      pathList = []
      pathList.push(json.FilePath) for json in manageDataJson
      for path in pathList
        promiseList.push(manageDataRead(bucket, path))
      Promise.all(promiseList).then((resultList) ->
        massege = "```【作業状況】\n"
        for result in resultList
          userDataJson = jsonFileRead(result)
          massege += "#{userDataJson[0].UserName}さんの残作業----------------------------------------------\n"
          massege += "(#{json.Sequence}) #{json.TaskName}\n     [#{getOutputDateTime(json.StratDateTime)}] ～ [#{setEndDateTime(json)}]\n" for json in userDataJson when tryGetDate(json.EndDateTime, null) is null
        massege += "```"
        sendMassege(msg, massege)
      )
    #作業管理リスト表示で無い場合は追加登録
    else
      userId = '' + msg.message.user.id #文字列に変換
      manageDataJson = manageDataJson.filter (item, index) ->
        if item.UserId == userId then return true
      if manageDataJson.length < 1
        manageDataJson.push(createNewManage(userId, createTodoPath(userId)))
        jsonFileWrite(bucket, createTodoRoomPath(userRoom), manageDataJson)
#-------------------------------------------------------------------------------
