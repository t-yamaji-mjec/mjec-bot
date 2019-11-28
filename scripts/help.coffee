# Description:
#   ヘルプ機能.
#
# Notes:
#   実行出来るコマンドの一覧を表示する.
#
# Commands:
#   ヘルプ,コマンド, - 実行出来るコマンドの一覧を表示する
#
module.exports = (robot) ->
  robot.respond /ヘルプ|コマンド/i, (msg) ->
    massege =  ">【翻訳機能】\n"
    massege += "> 　翻訳[model] [翻訳したい文字列] - [model]は以下を参照 \n"
    massege += "> 　https://cloud.ibm.com/docs/services/language-translator?topic=language-translator-translation-models&locale=ja#japanese \n\n"
    massege += ">【タイムカード機能】\n"
    massege += "> 　打刻出社 - 当日の出社時間を記録する \n"
    massege += "> 　打刻出社 [YYYY/MM/DD] [hh:mm or DEL] - 指定した日時の出社時間を修正する ※DELは内容をクリアします \n"
    massege += "> 　打刻退社 - 当日の退社時間を記録する \n"
    massege += "> 　打刻退社 [YYYY/MM/DD] [hh:mm or DEL] - 指定した日時の退社時間を修正する ※DELは内容をクリアします \n"
    massege += "> 　打刻備考 [備考] - 当日の備考を記録する \n"
    massege += "> 　打刻備考 [YYYY/MM/DD] [備考 or DEL] - 指定した日時の備考を修正する ※DELは内容をクリアします \n"
    massege += "> 　打刻削除 [YYYY/MM/DD] - 指定した日の打刻を削除する \n"
    massege += "> 　勤怠確認 - 当月の勤怠記録を出力する \n"
    massege += "> 　勤怠確認 [YYYY/MM] - 指定した月の勤怠記録を出力する \n\n"
    massege += ">【クイズ機能】\n"
    massege += "> 　クイズ [問題数] - 特定のファイルから取得したクイズを出題する \n"
    massege += "> 　クイズ採点 - 現在実行中のクイズを採点する \n"
    massege += "> 　A:[回答] - クイズに回答する、読み方(カナ)、名称、英名で受け付ける \n\n"
    massege += ">【静的コンテンツダウンロード機能】\n"
    massege += "> 　コンテンツリスト - 特定フォルダにあるファイルの一覧(No)を表示する\n"
    massege += "> 　コンテンツ [No] - 選択したファイルをSlack上に添付する\n"
    msg.send massege
