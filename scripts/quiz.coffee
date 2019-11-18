# Description:
#   クイズ機能.
#
# Notes:
#   用語の説明から回答を受け付けて採点する機能.
#
# Commands:
#  クイズ (n:問題数) (n:分) - 特定のファイルから取得したクイズを出題する
#  クイズ採点 - 現在実行中のクイズを採点する
#  A:(回答) - クイズに回答する
#
bucket = ""
userRoom = ""
CosDA = require('./cos_data_access')
module.exports = (robot) ->
  robot.hear /クイズ (\d+) (\d+)/i, (msg) ->
    getSetting(msg, "question")

  robot.hear /クイズ採点/i, (msg) ->
    getSetting(msg, "scoring")

  robot.hear /A:(.*)/i, (msg) ->
    getSetting(msg, "answer")

  getJstTime = ->
     d = new Date
     d.setTime(d.getTime() + 1000*60*60*9 ) #JSTに変換 + 指定時間を加算
     return d

  getEndTime = (addTime) ->
     jst = getJstTime()
     jst.setTime(jst.getTime() + (1000*60*addTime)) #指定時間分を加算
     return jst

  outputTime = (time) ->
     hour = (" "+time.getHours()).slice(-2)  # 時
     min = ("0"+time.getMinutes()).slice(-2) # 分
     sec = ("0"+time.getSeconds()).slice(-2) # 秒
     return "#{hour}:#{min}:#{sec}"

  createRandomNumber = (maxNumber) ->
    Math.floor(Math.random() * maxNumber)

  createQuestionData = (count,quizDataJson) ->
    arr = []
    maxIndex = quizDataJson.pop().No - 1
    for i in [0..(maxIndex + 100)]  #問題数が不足していた時の対策
      rnd = createRandomNumber(maxIndex)
      if quizDataJson[rnd].Exclude is 0 then arr.push(quizDataJson[rnd].No) #除外されていないものから抽出
      arr = arr.filter (x, i, self) -> self.indexOf(x) is i #重複を削除
      if arr.length >= count then return arr
    return arr

  createNewSetting = (count, endTime, quizDataJson) ->
    json = getSettingBase()
    json["Enable"] = 1
    json["QuestionCount"] = count
    json["EndTime"] = endTime
    json["QuestionIndex"] = 0
    json["QuestionData"] = createQuestionData(count, quizDataJson)
    json["UserScore"] = []
    return json

  getSettingBase = ->
    JSON.parse('{ "Enable":"","QuestionCount":"", "EndTime":"", "QuestionIndex":"", "QuestionData":"", "UserScore":""}')

  createUserScore = (userId, userName, score) ->
    json = getScoreBase()
    json["UserId"] = userId
    json["UserName"] = userName
    json["Score"] = score
    return json

  getScoreBase = ->
    JSON.parse('{"UserId":"","UserName":"","Score":""}')

  createSettingPath = (userRoom) ->
    "quiz_#{userRoom}.json"

  jsonFileRead = (data) ->
    JSON.parse(Buffer.from(data.Body).toString()) if data isnt null

  jsonFileWrite = (bucket, path, json) ->
    CosDA.doCreateObject(bucket, path, JSON.stringify(json))

  sortScore = (a, b) ->
    b.Score - a.Score

  getSetting = (msg, mode) ->
    path = require('path')
    bucket = '' + process.env['BUCKET_NAME']
    userRoom = '' + msg.message.user.room #文字列に変換
    settingData = CosDA.doGetObject(bucket, createSettingPath(userRoom)) #Promiseを返却
    settingData.then((data) -> getQuizData msg, mode, jsonFileRead(data)).catch(
                     (e) -> getQuizData msg, mode, "")

  getQuizData = (msg, mode, settingJson) ->
    quizData = CosDA.doGetObject(bucket, "quiz_question_data.json") #Promiseを返却
    quizData.then((data) -> quizLogic msg, mode, settingJson, jsonFileRead(data)).catch(
                  (e) -> console.log e)

  quizLogic = (msg, mode, settingJson, quizDataJson) ->
    #console.log settingJson
    #console.log quizDataJson
    userId = '' + msg.message.user.id #文字列に変換
    userName = '' + msg.message.user.name #文字列に変換
    nowTime = getJstTime()
    #クイズ開始の場合、引数を基にクイズ用設定データを生成して１問目を出題する
    if mode == "question"
      count = Number(msg.match[1])
      endTime = getEndTime(msg.match[2])
      outputEndTime = outputTime(endTime)
      outputSettingJson = createNewSetting(count, endTime, quizDataJson)
      massege = "クイズを開始します。問題数：#{count} 終了時間：#{outputEndTime}\n"
      massege += outputQuestion(outputSettingJson, quizDataJson)
    #クイズ採点の場合、終了処理を行い採点結果を表示する
    else if mode == "scoring"
      settingJson.Enable = 0
      massege = scoring(msg, settingJson)
      outputSettingJson = settingJson
    #クイズに回答した場合、回答内容に対して採点を行い、続く場合は次の問題を出題する
    else if mode == "answer"
      if settingJson.Enable is 0 then return
      answer = msg.match[1]
      {setting, result} = decisionQuiz(userId, userName, answer, settingJson, quizDataJson)
      massege = result
      console.log "index:#{setting.QuestionIndex}"
      console.log "count:#{setting.QuestionCount}"
      if setting.QuestionIndex is setting.QuestionCount
        setting.Enable = 0
        massege += scoring(setting)
      else
        massege += outputQuestion(setting, quizDataJson)
      outputSettingJson = setting
    jsonFileWrite(bucket, createSettingPath(userRoom), outputSettingJson)
    msg.send massege

  decisionQuiz = (userId, userName, answer, setting, quizData) ->
    quiz = getQuiz(setting, quizData)
    decision = if quiz[0].Reading is answer or quiz[0].Name is answer or quiz[0].EnglishName is answer then true else false
    userScore = setting.UserScore.filter (us) -> us.UserId is userId
    console.log userScore.length
    if userScore.length > 0
      for us in setting.UserScore when us.UserId is userId
        if decision then us.Score = us.Score + 1
    else
      firstScore = if decision then 1 else 0
      setting.UserScore.push(createUserScore(userId, userName, firstScore))
    setting.QuestionIndex = setting.QuestionIndex + 1
    if decision
      return {setting, result:"〇：#{quiz[0].Name} (#{quiz[0].EnglishName}) #{quiz[0].Description}\n\n"}
    else
      return {setting, result:"×：#{quiz[0].Name}(#{quiz[0].EnglishName})#{quiz[0].Description}\n\n"}

  getQuiz = (setting, quizData) ->
    index = setting.QuestionIndex
    if setting.Enable is 1 and index < setting.QuestionCount
      quiz = quizData.filter (data) -> data.No is setting.QuestionData[index]

  outputQuestion = (setting, quizData) ->
    quiz = getQuiz(setting, quizData)
    return "第#{setting.QuestionIndex+1}問 #{quiz[0].Description}"

  scoring = (settingJson) ->
    if settingJson.UserScore > 1 then settingJson.UserScore.sort sortScore
    massege = "【採点結果】\n"
    massege += "#{i+1}位：#{us.UserName} #{us.Score}点\n" for us,i in settingJson.UserScore
    return  massege
