# Tripo 佇列：loop 排、Jacky 本機產（D-270）

雲端 loop 連不到 Tripo（proxy 403），API 憑證也不放雲端；所以：

1. **loop**：把要的模型寫進 `queue.json` 的 `items`（一輪最多加 5 個），推上去，並在 `docs/FOR_JACKY.md` 寫一行「Tripo 佇列有 N 個待產（約 X 點）」。
2. **Jacky**（本機、repo 根目錄）：`git pull` → `python scripts/tripo_queue.py`（只估點數）→ `python scripts/tripo_queue.py --run --push`。
3. 產物出現在 `art-inbox/tripo/<id>/`（貼圖已縮到 1024 JPEG、單檔 ≤ 6 MB、不走 LFS，雲端拿得到）：
   - `<id>_model.glb`：生成的模型（PBR）
   - `<id>_rig.glb`：綁好骨的（有 `rig` 才有）
   - `<id>_anim.glb`：套了預設動作的（有 `animations` 才有）
   - `*_preview.jpg`、`SOURCE.json`（提示、task id、授權、AI 申報）
4. **loop 下一輪**：看預覽與 `SOURCE.json` → 用 bpy 檢查／修整（朝向、比例、原點、面數、材質數）→ 合格的複製到 `game/assets/...`、記進 `docs/CREDITS.md`。不合格的寫進 FOR_JACKY 並改提示重排（換 `id` 結尾 `_v2`）。

## 一個項目

```json
{
  "id": "market_stall_herbs",            // 小寫英數底線，也是資料夾名；產過（有 SOURCE.json）就不會再產
  "prompt": "...英文描述：形狀、材質、風格、尺寸...",
  "image": "art-inbox/refs/xxx.png",     // 二選一：用參考圖（必須是 repo 裡、已審過的圖）
  "model": "tripo-v3.1",                 // 小物／場景：tripo-v3.1（約 20 點，detailed 30 點）；要乾淨低面角色：tripo-p2（約 110 點）
  "params": {"face_limit": 8000, "texture_quality": "standard"},
  "negative_prompt": "text, logo, base, pedestal",
  "rig": {"type": "biped", "spec": "mixamo"},          // 角色才要；Godot 的 retarget 用 mixamo 名字比較好對
  "animations": ["preset:idle", "preset:walk", "preset:run"],  // 有 rig 才有效，最多 5 個；v3.0 骨架可用 idle/walk/run/jump/slash/shoot/hurt/fall/turn/dive/climb
  "note": "為什麼要這個、用在哪（NEXT 的哪一項）"
}
```

- 預算：`budget_credits_per_run`（預設 300 點 ≈ 3 美元）；超出的留到下次。只有 Jacky 可以改這個數字。
- 提示寫法：一律英文；寫出風格（`stylized dark fantasy, hand-painted look` 之類跟現有畫面一致的詞）、主要材質、大約尺寸；**不要寫真實品牌、既有作品或角色的名字**；人形角色加 `T-pose, full body, arms apart`。
- 授權：Tripo 付費帳號產出，商用權歸 Jacky；**不是 CC0**。上架時屬於 Steam 的「Pre-Generated AI content」，要申報。
- 什麼該用 Tripo、什麼不要：有機形體、雕刻感重的東西（怪物、雕像、樹根、岩石、攤位上的雜物、角色）用 Tripo；方正的建築、地面、可平鋪的牆面、程式能算的東西繼續用 bpy／程序化；現成 CC0 包（`art-inbox/props/`）有的就不要花點數。
