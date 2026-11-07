# 餘命城 / Yuming City

以原創小說《餘命城》為世界觀的 PC 單機敘事動作 RPG 開發專案。

## 目前狀態

前期企劃。已收錄完結小說及技術方向建議；尚未建立 Unreal 專案、製作遊戲資產或產出可執行遊戲。3A 是品質願景，並非已達成的製作規模。

## 目標

- 發行：Steam，優先 Windows 64-bit PC，有獨立 GPU 的玩家。
- 不規劃 iOS / Android；Linux、Steam Deck 暫不承諾支援。
- 建議類型：第三人稱、單人、章節式敘事動作 RPG，搭配城市據點。
- 核心：九息重現、可理解且有代價的記憶抉擇、同伴協作、城市存續。
- 感情：以席菈的一對一關係為主線，保留其他人物獨立動機與成長。

## 技術方向（待原型驗證）

Unreal Engine 5 + C++ + Blueprint，Windows / DirectX 12。

版本在確認編譯工具、必要外掛及打包測試後固定於專案；不要只因新版本發布就升級。

詳見 [技術決策](docs/technical-direction.md) 與 [首個可玩關卡](docs/vertical-slice.md)。

## 原作

[《餘命城》全篇完結小說](docs/story/yuming-city-complete.zh-TW.md)：四部、44 個編號章節，另含尾聲與終章。遊戲改編設計需與原作分開管理。

## 儲存庫約定

- 大型遊戲資產使用 Git LFS；已提供 `.gitattributes`，開始加入資產前執行 `git lfs install`。
- Unreal 生成快取、建置產物、機密與商店憑證不提交。
- 不把 Unreal Engine 引擎原始碼或安裝內容複製進此 repo。
- 本儲存庫未授予開源授權；第三方素材依各自授權管理。

第一步是製作並量測一段可玩的實機關卡，而非一次把全篇故事做成開放世界。
