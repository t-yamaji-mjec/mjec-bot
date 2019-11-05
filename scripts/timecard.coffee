# Description:
#   タイムカード機能
#
# Notes:
#   ユーザー毎に出社、退社時間を記録して、出力出来る機能
#
module.exports = (robot) ->
  robot.hear /打刻 出社/i, (msg) ->
    timecard(msg, "attend")

  robot.hear /打刻 退社/i, (msg) ->
    timecard(msg, "leave")

  robot.hear /修正 出社 (.*)/i, (msg) ->
    timecard(msg, "modify_attend")

  robot.hear /修正 退社 (.*)/i, (msg) ->
    timecard(msg, "modify_leave")

  robot.hear /勤怠記録/i, (msg) ->
    timecard(msg, "record")

  robot.hear /送信確認/i, (msg) ->
    timecard(msg, "check")

  #タイムカードメソッド
  timecard = (msg, mode) ->
    #console.log msg
    userId = msg.message.user.id
    userName = msg.message.user.name
    userRoom = msg.message.user.room
    msg.send "{UserId:#{userId},UserName:#{userName},UserRoom:#{userRoom}}"
    #msg.send "userName:#{userName}\nmode:#{mode}"
