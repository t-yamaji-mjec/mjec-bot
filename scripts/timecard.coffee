# Description:
#   タイムカード機能
#
# Notes:
#   ユーザー毎に出社、退社時間を記録して、出力出来る機能
#
# Commands:
#  打刻出社 - 当日の出社時間を記録する ※カスタム絵文字[:出社:]でも同様に反応する
#  打刻出社 [YYYY/MM/DD] [hh:mm or DEL] - 指定した日時の出社時間を修正する ※DELは内容をクリアします
#  打刻退社 - 当日の退社時間を記録する ※カスタム絵文字[:退社:]でも同様に反応する
#  打刻退社 [YYYY/MM/DD] [hh:mm or DEL] - 指定した日時の退社時間を修正する ※DELは内容をクリアします
#  打刻備考 [備考] - 当日の備考を記録する
#  打刻備考 [YYYY/MM/DD] [備考 or DEL] - 指定した日時の備考を修正する ※DELは内容をクリアします
#  打刻削除 [YYYY/MM/DD] - 指定した日の打刻を削除する
#  打刻確認 - 当月の勤怠記録を出力する
#  打刻確認 [YYYY/MM] - 指定した月の勤怠記録を出力する
#
CosDA = require('./_cos_data_access')
strEnpty = "空欄"
module.exports = (robot) ->

  robot.hear /打刻出社$/i, (msg) ->
    timecard(msg, "attend")
  robot.hear /(:|：)出社(:|：)/i, (msg) ->
    timecard(msg, "attend")
  robot.hear /打刻出社\s(\d+\/+\d+\/+\d+)\s((\d+:\d+)|DEL)$/i, (msg) ->
    timecard(msg, "modify_attend")

  robot.hear /打刻退社$/i, (msg) ->
    timecard(msg, "leave")
  robot.hear /(:|：)退社(:|：)/i, (msg) ->
    timecard(msg, "leave")
  robot.hear /打刻退社\s(\d+\/+\d+\/+\d+)\s((\d+:\d+)|DEL)$/i, (msg) ->
    timecard(msg, "modify_leave")

  robot.hear /打刻備考\s(.*)$/i, (msg) ->
    if /(\d+\/+\d+\/+\d+)/.test(msg.match[1])
    else
       timecard(msg, "note")
  robot.hear /打刻備考\s(\d+\/+\d+\/+\d+)\s((.*)|DEL)$/i, (msg) ->
    timecard(msg, "modify_note")

  robot.hear /打刻削除\s(\d+\/+\d+\/+\d+)$/i, (msg) ->
    timecard(msg, "delete")

  robot.hear /打刻確認$/i, (msg) ->
    timecard(msg, "record_now")
  robot.hear /打刻確認\s(\d+\/+\d+)$/i, (msg) ->
    timecard(msg, "record")

  getNowDate = ->
    d = new Date
    d.setTime((d.getTime() + 1000*60*60*9)) #JSTに変換
    year = d.getFullYear()   # 年（西暦）
    month = d.getMonth() + 1 # 月
    day =  d.getDate()       # 日
    return outputDate(year, month, day)

  getNowTime = ->
    d = new Date
    d.setTime((d.getTime() + 1000*60*60*9)) #JSTに変換
    hour = d.getHours() # 時
    min = d.getMinutes() # 分
    return outputTime(hour,min)

  outputDate = (year, month, day) ->
    return "#{year}/#{month}/#{day}"

  outputTime = (hour, min) ->
    return "#{hour}:#{min}"

  getOutputDate = (strDate) ->
    arr = strDate.split(/\//)
    outputDate(arr[0], (" " + arr[1]).slice(-2), (" " + arr[2]).slice(-2))

  getOutputTime = (strTime) ->
    if strTime is "" then return "     "
    arr = strTime.split(/:/)
    outputTime((" " + arr[0]).slice(-2), ("0" + arr[1]).slice(-2))

  createNewData = (userId, userName, date, attendTime, leaveTime, note) ->
    json = getTimeCardBase()
    json["UserId"] = userId
    json["UserName"] = userName
    json["Date"] = date
    json["AttendTime"] = attendTime
    json["LeaveTime"] = leaveTime
    json["Note"] = note
    console.log json
    return json

  getTimeCardBase = ->
    try
      JSON.parse('{"UserId":"","UserName":"","Date":"","AttendTime":"","LeaveTime":"","Note":""}')
    catch e
      console.log e

  createPath = (userId) ->
    "data/timecard_#{userId}.json"

  jsonFileRead = (data) ->
    JSON.parse(Buffer.from(data.Body).toString()) if data isnt null

  jsonFileWrite = (bucket, path, json) ->
    CosDA.doCreateObject(bucket, path, JSON.stringify(json))

  setExistDateTime = (userDataJson, userId, userName, date, attendTime, leaveTime, note) ->
    for json in userDataJson when (new Date(json.Date)).getTime() == (new Date(date)).getTime()
      console.log (new Date(json.Date)).getTime()
      console.log (new Date(date)).getTime()
      #空欄なら空文字を代入
      if attendTime is strEnpty then json.AttendTime = ""
      if leaveTime is strEnpty then json.LeaveTime = ""
      if note is strEnpty then json.Note = ""
      #空文字でないなら入力値
      if attendTime isnt "" and attendTime isnt strEnpty then json.AttendTime = attendTime
      if leaveTime isnt "" and leaveTime isnt strEnpty then json.LeaveTime = leaveTime
      if note isnt "" and note isnt strEnpty then json.Note = note
      #console.log userDataJson
      return userDataJson
    userDataJson.push(createNewData(userId, userName, date, attendTime, leaveTime, note))
    return userDataJson

  deleteData = (userDataJson, date) ->
    newUserData = userDataJson.filter (item, index) ->
      if (new Date(item.Date)).getTime() != (new Date(date)).getTime()
        return true #削除対象の日付を除外
    return newUserData

  sortdate = (a, b) ->
    (new Date(a.Date)).getTime() - (new Date(b.Date)).getTime()

  #タイムカードメソッド(初期化)
  timecard = (msg, mode) ->
    path = require('path')
    userId = '' + msg.message.user.id #文字列に変換
    bucket = process.env['BUCKET_NAME']
    userData = CosDA.doGetObject(bucket, createPath(userId)) #Promiseを返却
    userData.then((data) -> timecardLogic msg, bucket, userId, mode, jsonFileRead(data)).catch(
                  (e) -> timecardLogic msg, bucket, userId, mode, JSON.parse("[]"))

  getYearMonth = (date) ->
    /^(\d+)\/+(\d+)/.exec(date)[0]

  timecardLogic = (msg, bucket, userId, mode, userDataJson) ->
    #console.log userDataJson
    userName = '' + msg.message.user.name #文字列に変換
    nowDate = getNowDate()
    nowTime = getNowTime()
    if userDataJson.length > 1 then userDataJson.sort sortdate
    #勤怠記録の場合、ユーザーの該当月勤怠記録を出力して終了
    if mode == "record" or mode == "record_now"
      ym = if mode is "record_now" then getYearMonth(nowDate) else msg.match[1]
      massege = "```#{userName}さんの勤怠記録\n"
      massege += "#{getOutputDate(json.Date)} 出社[#{getOutputTime(json.AttendTime)}] 退社[#{getOutputTime(json.LeaveTime)}] 備考[#{json.Note}]\n" for json in userDataJson when getYearMonth(json.Date) is ym
      massege += "```"
    #打刻出勤の場合、当日データが有れば追記、無ければ新規作成
    else if mode == "attend"
      outputDataJson = setExistDateTime(userDataJson, userId, userName, nowDate, nowTime, "", "")
      jsonFileWrite(bucket, createPath(userId), outputDataJson)
      massege = "#{userName}さん 出社時間に#{getOutputTime(nowTime)}を登録しました"
    #打刻退勤の場合、当日データが有れば追記、無ければ新規作成
    else if mode == "leave"
      outputDataJson = setExistDateTime(userDataJson, userId, userName, nowDate, "", nowTime, "")
      jsonFileWrite(bucket, createPath(userId), outputDataJson)
      massege = "#{userName}さん 退社時間に#{getOutputTime(nowTime)}を登録しました"
    #打刻備考の場合、当日データが有れば追記、無ければ新規作成
    else if mode == "note"
      note = msg.match[1]
      outputDataJson = setExistDateTime(userDataJson, userId, userName, nowDate, "", "", note)
      jsonFileWrite(bucket, createPath(userId), outputDataJson)
      massege = "#{userName}さん 備考に#{note}を登録しました"
    #打刻削除の場合、該当日データを削除
    else if mode == "delete"
      deleteDate = msg.match[1]
      outputDataJson = deleteData(userDataJson, deleteDate)
      jsonFileWrite(bucket, createPath(userId), outputDataJson)
      massege = "#{userName}さん #{deleteDate}の打刻を削除しました"
    #打刻出社(日時有り)の場合、該当日データが有れば追記、無ければ何もしない
    else if mode == "modify_attend"
      modifyDate = msg.match[1]
      modifyTime = if ('' + msg.match[2]).toUpperCase() is "DEL" then strEnpty else msg.match[2]
      outputDataJson = setExistDateTime(userDataJson, userId, userName, modifyDate, modifyTime, "", "")
      jsonFileWrite(bucket, createPath(userId), outputDataJson)
      massege = "#{userName}さん #{modifyDate}の出社時間を#{(modifyTime)}に変更しました"
    #打刻退社(日時有り)の場合、該当日データが有れば追記、無ければ何もしない
    else if mode == "modify_leave"
      modifyDate = msg.match[1]
      modifyTime = if ('' + msg.match[2]).toUpperCase() is "DEL" then strEnpty else msg.match[2]
      outputDataJson = setExistDateTime(userDataJson, userId, userName, modifyDate, "", modifyTime, "")
      jsonFileWrite(bucket, createPath(userId), outputDataJson)
      massege = "#{userName}さん #{modifyDate}の退社時間を#{(modifyTime)}に変更しました"
    #打刻備考(日付有り)の場合、該当日データが有れば追記、無ければ何もしない
    else if mode == "modify_note"
      modifyDate = msg.match[1]
      modifyNote = if ('' + msg.match[2]).toUpperCase() is "DEL" then strEnpty else msg.match[2]
      outputDataJson = setExistDateTime(userDataJson, userId, userName, modifyDate, "", "", modifyNote)
      jsonFileWrite(bucket, createPath(userId), outputDataJson)
      massege = "#{userName}さん #{modifyDate}の備考を#{(modifyNote)}に変更しました"
    #console.log outputDataJson
    msg.send massege
