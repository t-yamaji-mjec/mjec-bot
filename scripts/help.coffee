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
    massege += "> 　翻訳リスト　[言語] - modelの一覧を表示する ※言語は省略可能\n"
    massege += "> 　翻訳[model]　[翻訳したい文字列] - [model]は翻訳リストのコマンドを参照 ※model省略時はen-jaを自動指定する \n"
    massege += "\n"
    massege += ">【タイムカード機能】\n"
    massege += "> 　打刻出社 - 当日の出社時間を記録する ※カスタム絵文字[:出社:]でも同様に反応する\n"
    massege += "> 　打刻出社　[YYYY/MM/DD]　[hh:mm or DEL] - 指定した日時の出社時間を修正する ※DELは内容をクリアします \n"
    massege += "> 　打刻退社 - 当日の退社時間を記録する  ※カスタム絵文字[:退社:]でも同様に反応する\n"
    massege += "> 　打刻退社　[YYYY/MM/DD]　[hh:mm or DEL] - 指定した日時の退社時間を修正する ※DELは内容をクリアします \n"
    massege += "> 　打刻備考　[備考] - 当日の備考を記録する \n"
    massege += "> 　打刻備考　[YYYY/MM/DD]　[備考 or DEL] - 指定した日時の備考を修正する ※DELは内容をクリアします \n"
    massege += "> 　打刻削除　[YYYY/MM/DD] - 指定した日の打刻を削除する \n"
    massege += "> 　打刻確認 - 当月の勤怠記録を出力する \n"
    massege += "> 　打刻確認　[YYYY/MM] - 指定した月の勤怠記録を出力する \n"
    massege += "\n"
    massege += ">【クイズ機能】\n"
    massege += "> 　クイズ　[問題数] - 特定のファイルから取得したクイズを出題する \n"
    massege += "> 　クイズ採点 - 現在実行中のクイズを採点する \n"
    massege += "> 　A:[回答] - クイズに回答する、読み方(カナ)、名称、英名で受け付ける \n"
    massege += "\n"
    massege += ">【静的コンテンツダウンロード機能】\n"
    massege += "> 　コンテンツリスト - 特定フォルダにあるファイルの一覧(No)を表示する\n"
    massege += "> 　コンテンツ　[No] - 選択したファイルをSlack上に添付する\n"
    massege += "\n"
    massege += ">【天気予報機能】\n"
    massege += "> 　天気エリア　[都道府県名] - 対象となるエリアの一覧(Name,ID)を出力する ※[都道府県名]は省略可能\n"
    massege += "> 　天気　[都市名 or 都市ID] - 対象都市の今日、明日、明後日の天気を表示する\n"
    massege += "\n"
    massege += ">【画像検索機能】\n"
    massege += "> 　画像検索　[名詞] - 画像をランダム検索する\n"
    massege += "> 　画像検索N　[名詞] - 画像を検索する(未編集)\n"
    massege += "\n"
    massege += ">【メッセージ削除機能】\n"
    massege += "> 　メッセージ削除 [削除件数] - BOTの発言を削除する ※[削除件数]を省略すると最新1件を対象\n"
    massege += "\n"
    massege += ">【TODO機能】\n"
    massege += "> 　作業開始　[作業名] - 新しく開始した作業を記録する\n"
    massege += "> 　作業中断　[番号] - 指定した作業を中断する\n"
    massege += "> 　作業終了　[番号] - 指定した作業を終了する\n"
    massege += "> 　作業削除　[番号] - 指定した作業を削除する\n"
    massege += "> 　作業一覧　 - 当日の作業一覧を出力する\n"
    massege += "> 　作業一覧　[YYYY/MM/DD] - 指定した日付の作業一覧を出力する\n"
    massege += "> 　作業管理 - チャンネル内の未終了作業を一覧出力する\n"
    msg.send massege
