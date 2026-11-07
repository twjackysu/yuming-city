# 素材與授權

遊戲內「製作人員／授權」畫面會依這份清單產生。新增任何第三方素材都要記在這裡：名稱、作者、授權、來源網址、用在哪裡、是否 AI 生成。

## 引擎與工具

| 名稱 | 授權 | 來源 | 用途 |
|---|---|---|---|
| Godot Engine 4.7.2 | MIT（另含第三方元件授權，見 Godot 的 `COPYRIGHT.txt`） | https://godotengine.org/license/ | 遊戲引擎；遊戲內需附授權聲明 |

## 字型

| 名稱 | 授權 | 來源 | 用途 |
|---|---|---|---|
| Noto Serif CJK TC（SemiBold，Serif 2.003） | SIL Open Font License 1.1 | https://github.com/notofonts/noto-cjk | 標題字型；建置時依用字子集化（`scripts/gen_fonts.py`） |
| Noto Sans CJK TC（Regular／Medium，Sans 2.004） | SIL Open Font License 1.1 | https://github.com/notofonts/noto-cjk | 介面字型；同上 |

## 程式生成素材

以下由本專案程式生成，無第三方授權問題：

- 標題畫面背景（`game/scenes/boot/title_fog.gdshader`）
- 遊戲圖示（`game/icon.svg`）
- 音效：鐘聲、第九聲鐘、鈍擊、弱點鈍擊、爪擊、斬擊、閃避風聲（`scripts/gen_sfx.py`，只用 Python 標準函式庫合成，建置時產生、不進 git）
- 角色與敵人外型：諾恩、席菈（程序人偶換配色＋斷劍）、灰巡者、送葬者（CSG／程序 mesh，霜紋前兆為程序扇形／圓形／直線）

## 第三方素材

（目前沒有）

## AI 生成素材

（目前沒有。Steam 上架時需申報。）
