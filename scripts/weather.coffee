# Description:
#  天気予報機能.
#
# Note:
#  Livedoor Weather Web Service から天気予報を取得して出力する。
#
# Commands:
#  天気エリア [都道府県名] - 対象となるエリアの一覧(Name,ID)を出力する ※[都道府県名]は省略可能
#  天気 [都市名 or 都市ID] - 対象都市の今日、明日、明後日の天気を表示する
#
bucket = ""
CosDA = require('./_cos_data_access')
module.exports = (robot) ->
  robot.hear /天気エリア$/i, (msg) ->
    GetWeatherArea(msg, "area")

  robot.hear /天気エリア\s(.*)$/i, (msg) ->
    GetWeatherArea(msg, "area_search")

  robot.hear /天気\s(.*)$/i, (msg) ->
    GetWeatherArea(msg, "weather")

  JsonFileRead = (data) ->
    JSON.parse(Buffer.from(data).toString()) if data isnt null

  JsonWeatherRead = (data) ->
    JSON.parse(data.replace(/\n\n/g, "\\n")) if data isnt null

  GetWeatherArea = (msg, mode) ->
    bucket = '' + process.env['BUCKET_NAME']
    weatherArea = CosDA.doGetObject(bucket, "data/weather_city.json") #Promiseを返却
    weatherArea.then((data) -> WeatherLogic msg, mode, JsonFileRead(data.Body)).catch(
                     (e) -> console.log e)

  ResponseIcon = (text) ->
    res1 = text.replace(/^晴れ$/, ":sunny:")
              .replace(/^曇り$/, ":cloud:")
              .replace(/^雨$/, ":umbrella_with_rain_drops:")
              .replace(/^雷$/, ":zap:")
              .replace(/^雷雨$/, ":thunder_cloud_and_rain:")
              .replace(/^雪$/, ":snowman:")
              .replace(/^竜巻$/, ":tornado:")
              .replace(/^霧$/, ":fog:")
    res2 = res1.replace(/晴/, ":sunny:")
              .replace(/曇/, ":cloud:")
              .replace(/雨/, ":umbrella_with_rain_drops:")
              .replace(/雷/, ":zap:")
              .replace(/雪/, ":snowman:")
              .replace(/暴風/, ":tornado:")
              .replace(/のち/, "→")
              .replace(/時々/, "…")
    if res2 is text then res2 = ":negative_squared_cross_mark:"
    return res2

  CreateForecastsMassege = (dayText, forecasts) ->
    maxCelsius = if forecasts.temperature.max is null then "ー" else forecasts.temperature.max.celsius
    minCelsius = if forecasts.temperature.min is null then "ー" else forecasts.temperature.min.celsius
    return "#{dayText}： #{ResponseIcon(forecasts.telop)} (#{forecasts.telop})　:thermometer:気温：最高#{maxCelsius}度　最低#{minCelsius}度\n"

  GetAreaList = (weatherArea, prefecture) ->
    regexp = new RegExp("#{prefecture}")
    massege = ''
    for wa in weatherArea
      if prefecture is "" or regexp.test(wa.Prefecture)
        massege += "【#{wa.Prefecture}】\n"
        massege += "  都市ID：#{city.ID}　都市名：#{city.Name}\n" for city in wa.City
    return massege

  WeatherLogic = (msg, mode, weatherArea) ->
    if mode is "area"
      msg.send GetAreaList(weatherArea,"")
    else if mode is "area_search"
      msg.send GetAreaList(weatherArea,msg.match[1])
    else if mode is "weather"
      request = require("request")
      args = msg.match[1]
      massege = ''
      for wa in weatherArea
        reqID = city.ID for city in wa.City when city.Name is args or city.ID is args
      if reqID?
        #console.log "reqID：#{reqID}"
        request.get
          url: "http://weather.livedoor.com/forecast/webservice/json/v1?city=#{reqID}"
        , (err, response) ->
          console.log response.body
          res = JsonWeatherRead(response.body)
          massege += "【#{res.title}】\n"
          massege += CreateForecastsMassege("今　日", res.forecasts[0])
          massege += CreateForecastsMassege("明　日", res.forecasts[1])
          if res.forecasts[2]? then massege += CreateForecastsMassege("明後日", res.forecasts[2])
          massege += "\n#{res.description.text}\n"
          msg.send massege
