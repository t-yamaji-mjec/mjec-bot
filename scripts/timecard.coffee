# Description:
#   タイムカード機能
#
# Notes:
#   ユーザー毎に出社、退社時間を記録して、出力出来る機能
#
# Commands:
#  打刻出社 - 当日の出社時間を記録する
#  打刻退社 - 当日の退社時間を記録する
#  打刻退社 (備考) - 当日の備考を記録する
#  打刻削除 [YYYY/MM/DD] - 指定した日の打刻を削除する
#  修正出社 [YYYY/MM/DD] [hh:mm] - 指定した日時の出社時間を修正する
#  修正退社 [YYYY/MM/DD] [hh:mm] - 指定した日時の退社時間を修正する
#  修正備考 [YYYY/MM/DD] (備考) - 指定した日時の備考を修正する
#  勤怠確認  - 勤怠記録を出力する ※将来的に当月指定などを入れる予定
#
CosDA = require('./cos_data_access')
module.exports = (robot) ->
  robot.hear /打刻出社/i, (msg) ->
    timecard(msg, "attend")

  robot.hear /打刻退社/i, (msg) ->
    timecard(msg, "leave")

  robot.hear /打刻備考 (.*)/i, (msg) ->
    timecard(msg, "note")

  robot.hear /打刻削除 (\d+\D+\d+\D+\d+)/i, (msg) ->
    timecard(msg, "delete")

  robot.hear /修正出社 (\d+\D+\d+\D+\d+) (\d+:\d+)/i, (msg) ->
    timecard(msg, "modify_attend")

  robot.hear /修正備考 (\d+\D+\d+\D+\d+) (.*)/i, (msg) ->
    timecard(msg, "modify_note")

  robot.hear /修正退社 (\d+\D+\d+\D+\d+) (\d+:\d+)/i, (msg) ->
    timecard(msg, "modify_leave")

  robot.hear /勤怠確認/i, (msg) ->
    timecard(msg, "record")

  getDate = (date) ->
    if date.toString() is "Invalid Date" then return ''
    year = date.getFullYear()                     # 年（西暦）
    month = (" " + (date.getMonth() + 1)).slice(-2) # 月
    date = (" " + date.getDate()).slice(-2)         # 日
    return "#{year}/#{month}/#{date}"

  getTime = (date) ->
    if date.toString() is "Invalid Date" then return ''
    hour = (" "+ date.getHours()).slice(-2)  # 時
    min = ("0" + date.getMinutes()).slice(-2) # 分
    return "#{hour}:#{min}"

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
    "timecard_#{userId}.json"

  jsonFileRead = (data) ->
    JSON.parse(Buffer.from(data.Body).toString()) if data isnt null

  jsonFileWrite = (bucket, path, json) ->
    CosDA.doCreateObject(bucket, path, JSON.stringify(json))

  setExistDateTime = (userDataJson, userId, userName, date, attendTime, leaveTime, note) ->
    for json in userDataJson when (new Date(json.Date)).getTime() == (new Date(date)).getTime()
      if attendTime isnt "" then json.AttendTime = attendTime
      if leaveTime isnt "" then json.LeaveTime = leaveTime
      if note isnt "" then json.Note = note
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

  timecardLogic = (msg, bucket, userId, mode, userDataJson) ->
    #console.log userDataJson
    userName = '' + msg.message.user.name #文字列に変換
    d = new Date
    jstTime = d.setTime((d.getTime() + 1000*60*60*9)) #JSTに変換
    nowDate = getDate(new Date(jstTime))
    nowTime = getTime(new Date(jstTime))
    if userDataJson.length > 1 then userDataJson.sort sortdate
    #勤怠記録の場合、該当ユーザーの勤怠記録を出力して終了
    if mode == "record"
      massege = "#{userName}さんの勤怠記録\n"
      massege += "#{getDate(new Date(json.Date))} 出社[#{getTime(new Date(json.AttendTime))}] 退社[#{getTime(new Date(json.LeaveTime))}] 備考[#{json.Note}]\n" for json in userDataJson
    #打刻出勤の場合、当日データが有れば追記、無ければ新規作成
    else if mode == "attend"
      outputDataJson = setExistDateTime(userDataJson, userId, userName, nowDate, nowTime, "", "")
      jsonFileWrite(bucket, createPath(userId), outputDataJson)
      massege = "#{userName}さん 出社時間に#{nowTime}を登録しました"
    #打刻退勤の場合、当日データが有れば追記、無ければ新規作成
    else if mode == "leave"
      outputDataJson = setExistDateTime(userDataJson, userId, userName, nowDate, "", nowTime, "")
      jsonFileWrite(bucket, createPath(userId), outputDataJson)
      massege = "#{userName}さん 退社時間に#{nowTime}を登録しました"
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
    #修正出勤の場合、該当日データが有れば追記、無ければ何もしない
    else if mode == "modify_attend"
      modifyDate = msg.match[1]
      modifyTime = msg.match[2]
      outputDataJson = setExistDateTime(userDataJson, userId, userName, modifyDate, modifyTime, "", "")
      jsonFileWrite(bucket, createPath(userId), outputDataJson)
      massege = "#{userName}さん #{modifyDate}の出社時間を#{modifyTime}に変更しました"
    #修正退勤の場合、該当日データが有れば追記、無ければ何もしない
    else if mode == "modify_leave"
      modifyDate = msg.match[1]
      modifyTime = msg.match[2]
      outputDataJson = setExistDateTime(userDataJson, userId, userName, modifyDate, "", modifyTime, "")
      jsonFileWrite(bucket, createPath(userId), outputDataJson)
      massege = "#{userName}さん #{modifyDate}の退社時間を#{modifyTime}に変更しました"
    else if mode == "modify_note"
      modifyDate = msg.match[1]
      modifyNote = msg.match[2]
      outputDataJson = setExistDateTime(userDataJson, userId, userName, modifyDate, "", "", modifyNote)
      jsonFileWrite(bucket, createPath(userId), outputDataJson)
      massege = "#{userName}さん #{modifyDate}の備考を#{modifyNote}に変更しました"
    #console.log outputDataJson
    msg.send massege
