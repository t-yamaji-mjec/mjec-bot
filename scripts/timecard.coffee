# Description:
#   タイムカード機能
#
# Notes:
#   ユーザー毎に出社、退社時間を記録して、出力出来る機能
#
# Commands:
#  打刻出社 - 当日の出社時間を記録する
#  打刻退社 - 当日の退社時間を記録する
#  打刻削除 [YYYY/MM/DD] - 当日の退社時間を記録する
#  修正出社 [YYYY/MM/DD] [hh:mm] - 指定した日時の出社時間を修正する
#  修正退社 [YYYY/MM/DD] [hh:mm] - 指定した日時の退社時間を修正する
#  勤怠記録  - 勤怠記録を出力する ※将来的に当月指定などを入れる予定
#
cosDA = null
module.exports = (robot) ->
  CosDA = require('./cos_data_access')
  cosDA = new CosDA robot
  robot.hear /打刻出社/i, (msg) ->
    timecard(msg, "attend")

  robot.hear /打刻退社/i, (msg) ->
    timecard(msg, "leave")

  robot.hear /打刻削除 (\d+\D+\d+\D+\d+)/i, (msg) ->
    timecard(msg, "delete")

  robot.hear /修正出社 (\d+\D+\d+\D+\d+) (\d+:\d+)/i, (msg) ->
    timecard(msg, "modify_attend")

  robot.hear /修正退社 (\d+\D+\d+\D+\d+) (\d+:\d+)/i, (msg) ->
    timecard(msg, "modify_leave")

  robot.hear /勤怠記録/i, (msg) ->
    timecard(msg, "record")

  getDate = ->
    d = new Date
    d.setTime(d.getTime() + 1000*60*60*9) #JSTに変換
    year = d.getFullYear()     # 年（西暦）
    month = (d.getMonth() + 1) # 月
    date = d.getDate()         # 日
    return "#{year}/#{month}/#{date}"

  getTime = ->
     d = new Date
     d.setTime(d.getTime() + 1000*60*60*9) #JSTに変換
     hour = d.getHours()  # 時
     min = d.getMinutes() # 分
     return "#{hour}:#{min}"

  createNewData = (userId, userName, date, attendTime, leaveTime) ->
    json = getTimeCardBase()
    json["UserId"] = userId
    json["UserName"] = userName
    json["Date"] = date
    json["AttendTime"] = attendTime
    json["LeaveTime"] = leaveTime
    return json

  getTimeCardBase = ->
    try
      JSON.parse('{"UserId":"","UserName":"","Date":"","AttendTime":"","LeaveTime":""}')
    catch e
      console.log e

  createPath = (userId) ->
    "timecard_#{userId}.json"

  jsonFileRead = (data) ->
    JSON.parse(Buffer.from(data.Body).toString()) if data isnt null

  jsonFileWrite = (bucket, path, json) ->
    cosDA.doCreateObject(bucket, path, JSON.stringify(json))

  setAttendTime = (bucket, path, userId, userName, date, time) ->
    cosDA.doGetObject(bucket, path).then(
      (data) -> jsonFileWrite(bucket, path, setAttendTimeLogic(jsonFileRead(data), userId, userName, date, time))).catch(
      (e) -> jsonFileWrite(bucket, path, createNewData(userId, userName, date, time, "")))

  setAttendTimeLogic = (userDataJson, userId, userName, date, time) ->
    existDate = json.Date for json in userDataJson when json.Date == date
    if existDate?
      json.AttendTime = time for json in userDataJson when json.Date == date
    else
      userDataJson.push(createNewData(userId, userName, date, time, ""))
    return userDataJson

  setLeaveTime = (bucket, path, userId, userName, date, time) ->
    cosDA.doGetObject(bucket, path).then(
      (data) -> jsonFileWrite(bucket, path, setLeaveTimeLogic(jsonFileRead(data), userId, userName, date, time))).catch(
      (e) -> jsonFileWrite(bucket, path, createNewData(userId, userName, date, "", time)))

  setLeaveTimeLogic = (userDataJson, userId, userName, date, time) ->
    existDate = json.Date for json in userDataJson when json.Date == date
    if existDate?
      json.LeaveTime = time for json in userDataJson when json.Date == date
    else
      userDataJson.push(createNewData(userId, userName, date, "", time))
    return userDataJson

  deleteData = (bucket, path, userId, userName, date, time) ->
    cosDA.doGetObject(bucket, path).then(
      (data) -> jsonFileWrite(bucket, path, deleteDataLogic(jsonFileRead(data), date))).catch()

  deleteDataLogic = (userDataJson, date) ->
    newUserData = userDataJson.filter (item, index) ->
      if item.Date.toString() != date.toString()
        return true #削除対象の日付を除外
    return newUserData

  #タイムカードメソッド
  timecard = (msg, mode) ->
    path = require('path')
    userId = '' + msg.message.user.id #文字列に変換
    userName = '' + msg.message.user.name #文字列に変換
    bucket = process.env['BUCKET_NAME']
    nowDate = getDate()
    nowTime = getTime()
    #userDataJson.sort (a, b) -> a.Date - b.Date
    #console.log userFileJson

    #勤怠記録の場合、該当ユーザーの勤怠記録を出力して終了
    if mode == "record"
      msg.send outRecord = "#{userName}さんの勤怠記録\n"
      cosDA.doGetObject(bucket, createPath(userId)).then(
        (data) -> msg.send "#{json.Date} 出社[#{json.AttendTime}] 退社[#{json.LeaveTime}]\n" for json in jsonFileRead(data)).catch()
      return

    #打刻 出勤の場合、当日データが有れば追記、無ければ新規作成
    if mode == "attend"
      setAttendTime(bucket, createPath(userId), userId, userName, nowDate, nowTime)
      massege = "#{userName}さん 出社時間#{nowTime}を登録しました"
    #打刻 退勤の場合、当日データが有れば追記、無ければ新規作成
    else if mode == "leave"
      setLeaveTime(bucket, createPath(userId), userId, userName, nowDate, nowTime)
      massege = "#{userName}さん 退社時間#{nowTime}を登録しました"
    #打刻 削除の場合、該当日データを削除
    else if mode == "leave"
      deleteDate = msg.match[1]
      deleteData(bucket, createPath(userId), deleteDate)
      massege = "#{userName}さん 退社時間#{nowTime}を登録しました"
    #修正 出勤の場合、該当日データが有れば追記、無ければ何もしない
    else if mode == "modify_attend"
      modifyDate = msg.match[1]
      modifyTime = msg.match[2]
      setAttendTime(bucket, createPath(userId), userId, userName, modifyDate, modifyTime)
      massege = "#{userName}さん #{modifyDate}の出社時間を#{modifyTime}に変更しました"
    #修正 退勤の場合、該当日データが有れば追記、無ければ何もしない
    else if mode == "modify_leave"
      modifyDate = msg.match[1]
      modifyTime = msg.match[2]
      setLeaveTime(bucket, createPath(userId), userId, userName, modifyDate, modifyTime)
      massege = "#{userName}さん #{modifyDate}の退社時間を#{modifyTime}に変更しました"
    msg.send massege
