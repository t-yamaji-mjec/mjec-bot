# Description:
#   クイズ機能.
#
# Notes:
#   用語の説明を出題して、回答を受け付けて採点する機能.
#
# Commands:
#  クイズ (問題数) - 特定のファイルから取得したクイズを出題する
#  クイズ採点 - 現在実行中のクイズを採点する
#  A:(回答) - クイズに回答する、読み方(カナ)、名称、英名で受け付ける
#
bucket = ""
userRoom = ""
CosDA = require('./_cos_data_access')
module.exports = (robot) ->
  robot.hear /クイズ\s(\d+)/i, (msg) ->
    getSetting(msg, "question")

  robot.hear /クイズ採点/i, (msg) ->
    getSetting(msg, "scoring")

  robot.hear /A:(.*)/i, (msg) ->
    getSetting(msg, "answer")

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

  createNewSetting = (count, quizDataJson) ->
    json = getSettingBase()
    json["Enable"] = 1
    json["QuestionCount"] = count
    json["QuestionIndex"] = 0
    json["QuestionData"] = createQuestionData(count, quizDataJson)
    json["UserScore"] = []
    return json

  getSettingBase = ->
    JSON.parse('{ "Enable":"","QuestionCount":"", "QuestionIndex":"", "QuestionData":"", "UserScore":""}')

  createUserScore = (userId, userName, score, correct, mistake) ->
    json = getScoreBase()
    json["UserId"] = userId
    json["UserName"] = userName
    json["Score"] = score
    json["Correct"] = correct
    json["Mistake"] = mistake
    return json

  getScoreBase = ->
    JSON.parse('{"UserId":"","UserName":"","Score":"","Correct":"","Mistake":""}')

  createSettingPath = (userRoom) ->
    "data/quiz_#{userRoom}.json"

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
    quizData = CosDA.doGetObject(bucket, "data/quiz_question_data.json") #Promiseを返却
    quizData.then((data) -> quizLogic msg, mode, settingJson, jsonFileRead(data)).catch(
                  (e) -> console.log e)

  getQuiz = (setting, quizData) ->
    index = setting.QuestionIndex
    if setting.Enable is 1 and index < setting.QuestionCount
      quiz = quizData.filter (data) -> data.No is setting.QuestionData[index]

  quizLogic = (msg, mode, settingJson, quizDataJson) ->
    #console.log settingJson
    #console.log quizDataJson
    userId = '' + msg.message.user.id #文字列に変換
    userName = '' + msg.message.user.name #文字列に変換
    outputSetting = settingJson
    massege = ''
    #クイズ開始の場合、引数を基にクイズ用設定データを生成して１問目を出題する
    if mode == "question"
      count = Number(msg.match[1])
      massege += "クイズを開始します。問題数：#{count} \n"
      {outSetting, outMassege} = outputQuestion(createNewSetting(count, quizDataJson), quizDataJson)
      massege += outMassege
      outputSetting = outSetting
    #クイズ採点の場合、終了処理を行い採点結果を表示する
    else if mode == "scoring"
      {scorSetting, scorMassege} = scoring(settingJson)
      massege += scorMassege
      outputSetting = scorSetting
    #クイズに回答した場合、回答内容に対して採点を行い、続く場合は次の問題を出題する
    else if mode == "answer"
      if settingJson.Enable is 0 then return
      answer = msg.match[1]
      {decSetting, decMassege} = decisionQuiz(userId, userName, answer, settingJson, quizDataJson)
      massege += decMassege
      #console.log "index:#{setting.QuestionIndex}"
      #console.log "count:#{setting.QuestionCount}"
      if decSetting.QuestionIndex is decSetting.QuestionCount
        {scorSetting, scorMassege} = scoring(decSetting)
        massege += scorMassege
        outputSetting = scorSetting
      else
        {outSetting, outMassege} = outputQuestion(decSetting, quizDataJson)
        massege += outMassege
        outputSetting = outSetting
    jsonFileWrite(bucket, createSettingPath(userRoom), outputSetting)
    msg.send massege

  decisionQuiz = (userId, userName, answer, setting, quizData) ->
    quiz = getQuiz(setting, quizData)
    answerUpper = answer.toUpperCase()
    decision = if quiz[0].Reading is answerUpper or quiz[0].Name.toUpperCase() is answerUpper or quiz[0].EnglishName.toUpperCase() is answerUpper then true else false
    userScore = setting.UserScore.filter (us) -> us.UserId is userId
    #console.log "length:#{userScore.length}"
    if userScore.length > 0
      for us in setting.UserScore when us.UserId is userId
        if decision then us.Correct += 1 else us.Mistake += 1
        us.Score = us.Correct - us.Mistake
    else
      score = correct = mistake = 0
      if decision then correct = 1 else mistake = 1
      score = correct - mistake
      setting.UserScore.push(createUserScore(userId, userName, score, correct, mistake))
    setting.QuestionIndex = setting.QuestionIndex + 1
    if decision
      decMassege = "〇：#{quiz[0].Name} (#{quiz[0].EnglishName}) #{quiz[0].Description}\n\n"
    else
      decMassege = "×：#{quiz[0].Name} (#{quiz[0].EnglishName}) #{quiz[0].Description}\n\n"
    return {decSetting:setting, decMassege}

  outputQuestion = (setting, quizData) ->
    quiz = getQuiz(setting, quizData)
    outMassege = "第#{setting.QuestionIndex+1}問 #{quiz[0].Description}"
    return {outSetting:setting, outMassege}

  scoring = (setting) ->
    setting.Enable = 0
    if setting.UserScore.length > 1 then setting.UserScore.sort sortScore
    scorMassege = "【採点結果】\n"
    scorMassege += "#{i+1}位：#{us.UserName} #{us.Score}点 正解：#{us.Correct} 不正解：#{us.Mistake}\n" for us,i in setting.UserScore
    return {scorSetting:setting, scorMassege}
