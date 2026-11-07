# 技術調査と設計の判断

Menu Bar CleanerのMVPを作る前に、他アプリのメニューバー項目を、何をどこまで制御できるかを調べた記録。2026年11月7日に、macOS 26.4.1（Mac16,5、ノッチ付きのMacBook Pro）で確かめた。

## 結論

- 隠す：区切りの状態アイコン（NSStatusItem）の長さを伸ばし、その左の項目を画面の外へ押し出す。公開APIだけで動き、権限は要らない
- 並べ替え：macOSの標準の⌘ドラッグに任せる。アプリは並べ替えを実装しない
- 呼び出し：区切りの長さを戻す。トグルのクリック、⌃⌥⌘B、自動で隠すタイマー
- ノッチの裏の項目：Accessibility APIで一覧にし、AXPressで開く。アクセシビリティの権限が要る

## 操作ごとの検証

他アプリのアイコンについて、検出・並べ替え・非表示・再表示を分けて確かめた。

| 操作 | 方式 | 権限 | 実機での結果 |
| --- | --- | --- | --- |
| 検出 | 各アプリの`AXExtrasMenuBar`の子要素を読む | アクセシビリティ | 取れた。アプリ名、位置、大きさ、説明、`AXPress`の操作 |
| 検出（権限なし） | `CGWindowListCopyWindowInfo`でlayer 25のウィンドウを読む | 不要 | 使えない。macOS 26では持ち主がすべて「コントロールセンター」になり、どのアプリの項目か区別できない |
| 並べ替え | 利用者の⌘ドラッグ（macOSの標準の操作） | 不要 | 合成した⌘ドラッグで、項目が区切りの右へ移り、折りたたんでも表示されたまま残った |
| 非表示 | 区切りの`NSStatusItem.length`を画面の幅より長くする | 不要 | 区切りより左の項目の`x`座標が負になり、画面から消えた。アプリのメニュー（ファイル、編集など）は残った |
| 再表示 | 区切りの長さを14ptに戻す | 不要 | 元の位置に戻った |
| ノッチの裏の項目を開く | `AXUIElementPerformAction(kAXPressAction)` | アクセシビリティ | ノッチの裏で見えないGoogle Driveの項目を押すと、Driveの画面が開いた |

## 採用しなかった方式

| 方式 | 採用しなかった理由 |
| --- | --- |
| トグル自体を伸ばして区切りを兼ねさせる（状態アイコンを1つにする） | macOS 26では、長く伸ばした状態アイコンはまるごと描かれなくなり、トグルが見えなくなる。左端が画面の内側にあっても（x=24、長さ996pt）、外側にはみ出しても（x=-56）、矢印は表示されなかった。そのため、押し出す役の区切り（隠しているときは見えない）と、見えるトグルの2つに分けている |
| 項目の画像を撮って別のパネルに並べる（IceのIce Bar、Bartender） | 画面収録の権限が要る。画像の取得とクリックの中継で実装が大きくなる。MVPは名前の一覧とAXPressで足りる |
| CGEventで⌘ドラッグを合成して、アプリが項目を並べ替える（Ice） | アクセシビリティの権限が要り、macOSの版ごとに壊れやすい（IceはmacOS 26で不具合の報告が多い）。利用者が自分で⌘ドラッグすれば足りる |
| 非公開API | 使っていない。macOSの更新で壊れたときに直せないため |

## 依存しているOSの挙動

公開APIだけを使っているが、次の挙動はドキュメントに書かれた仕様ではなく、OSの更新で変わり得る。

- 長い状態アイコンに押し出された項目を、macOSが表示しないこと（hidden系のアプリと同じ方式）
- `NSStatusItem.length`の上限が10,000ptであること
- `autosaveName`を付けた状態アイコンの位置を、macOSが`NSStatusItem Preferred Position <名前>`として保存すること
- `AXExtrasMenuBar`で他アプリの状態アイコンが取れること
- 新しく現れた状態アイコンが、ほかの項目の左端に置かれること（hiddenの文書による。このMacでは確かめていない。左端に置かれると、新しいアイコンは最初から隠れる）

AXに依存する部分は`Sources/MenuBarCleaner/MenuBarItems.swift`に集めた。

macOS 27のベータでは、メニューバーの作り直しにより、長さを伸ばす方式が動かないという報告がある（hiddenのforkのリリースノートとissue）。macOS 27では確かめていない。

## 権限

| 権限 | 用途 | ないとき |
| --- | --- | --- |
| なし | 隠す、表示する、ショートカット、自動で隠す、ログイン時の起動 | ― |
| アクセシビリティ | 「隠れている項目」の一覧と、そこから項目を開く | 一覧の代わりに「一覧にはアクセシビリティの許可が必要です」と「許可する…」を出す |

画面収録と入力監視の権限は使わない。グローバルショートカットはCarbonの`RegisterEventHotKey`で登録するため、入力監視の権限は要らない。

アドホック署名のため、ビルドし直すとコードの署名が変わり、アクセシビリティの許可をやり直す必要が出ることがある。

## ノッチ付きのMac

- 項目がノッチと重なると、macOSはその項目を表示しない。AXでは`x`座標が負か、表示されていない位置になる
- 実機では、展開したときにGoogle DriveとRunCat Neoがノッチの裏に入り、見えなくなった
- そうした項目は、トグルの右クリック→「隠れている項目」に並び、AXPressで開ける。区切りより左にある項目が一覧に入る

## 参考

- [hidden（Hidden Bar）のARCHITECTURE.md](https://raw.githubusercontent.com/dwarvesf/hidden/HEAD/docs/ARCHITECTURE.md)：区切りの長さを伸ばして隠す方式
- [hiddenのforkのリリースノート](https://github.com/m-samoylov/hidden/releases)：macOS 27で長さを伸ばす方式が壊れたという報告
- [Iceのissue #679](https://github.com/jordanbaird/Ice/issues/679)、[#710](https://github.com/jordanbaird/Ice/issues/710)：macOS 26での不具合
- [SketchyBarのPR #789](https://github.com/FelixKratz/SketchyBar/pull/789)：macOS 26で状態アイコンの持ち主がコントロールセンターになった件
- [The Icons Behind The Notch](https://jorvik-software.pages.dev/notes/2026/05/03/the-icons-behind-the-notch)：AXExtrasMenuBarで状態アイコンを列挙する方法
