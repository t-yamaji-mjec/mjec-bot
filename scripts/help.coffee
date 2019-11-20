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
  robot.respond /[ヘルプ|コマンド]/i, (msg) ->
    massege =  ">【翻訳機能】\n"
    massege += "> 　翻訳[model] [翻訳したい文字列] - [model]は以下を参照 \n"
    massege += "> 　https://cloud.ibm.com/docs/services/language-translator?topic=language-translator-translation-models&locale=ja#japanese \n\n"
    massege += ">【タイムカード機能】\n"
    massege += "> 　打刻出社 - 当日の出社時間を記録する \n"
    massege += "> 　打刻退社 - 当日の退社時間を記録する \n"
    massege += "> 　打刻退社 [備考] - 当日の備考を記録する \n"
    massege += "> 　打刻削除 [YYYY/MM/DD] - 指定した日の打刻を削除する \n"
    massege += "> 　修正出社 [YYYY/MM/DD] [hh:mm] - 指定した日時の出社時間を修正する \n"
    massege += "> 　修正退社 [YYYY/MM/DD] [hh:mm] - 指定した日時の退社時間を修正する \n"
    massege += "> 　修正備考 [YYYY/MM/DD] [備考] - 指定した日時の備考を修正する \n"
    massege += "> 　勤怠確認  - 勤怠記録を出力する ※将来的に当月指定などを入れる予定 \n\n"
    massege += ">【クイズ機能】\n"
    massege += "> 　クイズ [問題数] - 特定のファイルから取得したクイズを出題する \n"
    massege += "> 　クイズ採点 - 現在実行中のクイズを採点する \n"
    massege += "> 　A:[回答] - クイズに回答する、読み方(カナ)、名称、英名で受け付ける \n"
    msg.send massege
