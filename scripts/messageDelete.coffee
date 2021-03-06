# Description:
#   メッセージ削除機能.
#
# Notes:
#   BOTから発信したメッセージを削除する.
#
# Commands:
#   メッセージ削除 [削除件数] - BOTの発言を削除する
#
cronJob = require('cron').CronJob
module.exports = (robot) ->

  robot.hear /メッセージ削除$/i, (msg) ->
    getMessageHistory(msg, 1)

  robot.hear /メッセージ削除\s(\d+)$/i, (msg) ->
    getMessageHistory(msg, Number(msg.match[1]))

  getMessageHistory = (msg, delCount) ->
    request = require("request")
    token = process.env['HUBOT_SLACK_TOKEN']
    channel = process.env['SLACK_CHANNEL']
    option = "?token=#{token}&channel=#{channel}&pretty=1"

    request.get
      url: "https://slack.com/api/channels.history#{option}"
    , (err, res) ->
      json = JSON.parse(res.body)
      cnt = 0
      for message in json.messages
        if message.bot_profile?
          cnt += 1
          deleteMessage(msg, message.ts)
          if cnt is delCount then break

  deleteMessage = (msg, ts) ->
    request = require("request")
    token = process.env['HUBOT_SLACK_TOKEN']
    channel = process.env['SLACK_CHANNEL']
    option = "?token=#{token}&channel=#{channel}&ts=#{ts}&pretty=1"
    request.get
      url: "https://slack.com/api/chat.delete#{option}"
    , (err, res) ->
