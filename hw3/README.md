# HW3 簽署檔案與獨立簽名驗證

題目來源：[More GPG examples](https://hackmd.io/b5RNk-hgSwq7NKmQwD80vg#HW3LAB)的 HW3/LAB。

進度：已於 2026-10-06 完成，尚未繳交。

## 題目與要求

本次作業有兩小題：

1. 檢查兩份簽署檔案，找出簽章正確的檔案。
2. 檢查兩份獨立簽名，找出正確的簽名。

驗證結果為：第一題選 **signed file 1（`dp.src1.asc`）**，第二題選 **signature file 2（`dp.src2.sig`）**。以下保留操作步驟與判斷依據。

[返回作業總覽與繳交方式](../README.md)

## 操作步驟

本次使用 Windows 上 Git for Windows 附帶的 GnuPG 2.4.9，並以 Python 3 取出原始文字。以下指令在 Git Bash 中，於本作業的 `hw3` 目錄執行。`python` 須指向已安裝的 Python 3。

### 1. 下載題目檔案並核對金鑰

先執行 `mkdir -p input output`，將以下五份檔案下載到 `input/`，保留原檔名：

| 題目標籤 | 檔案 |
| --- | --- |
| public key | [cnchen.pkey](https://mega.nz/file/6IhhAbiQ#XogtFtj7wgoyPRPzrLhXOkFz8uTUwz9zUmfCbgHh7P0) |
| signed file 1 | [dp.src1.asc](https://mega.nz/file/7EogUQxT#1b5O0eGUzi0zyOqPN0Xcmfse6rW8TGdBtpvZOthPafY) |
| signed file 2 | [dp.src2.asc](https://mega.nz/file/7cwFQIaQ#hnYnyg_hsn6PvTERE8D19LhMe7TPTdO0cPbtw8EFyvA) |
| signature file 1 | [dp.src1.sig](https://mega.nz/file/nAQ3kS5C#hn1H-fB9mnhj74AvNFRGD7v3Gd-2A-I4fsJkK5ItKas) |
| signature file 2 | [dp.src2.sig](https://mega.nz/file/ydA1TSgR#TFH7RFTqcIjGZnphFM8qJEAIxxZlphgWlR0_iBY5Fms) |

建立獨立金鑰目錄並匯入公開金鑰：

```bash
gpg_home="$(mktemp -d)"
gpg --homedir "$gpg_home" --import input/cnchen.pkey
gpg --homedir "$gpg_home" --fingerprint
```

本次讀到的主金鑰指紋與講義相同：

```text
36CE 32B4 A421 ABE0 2C4F AEB1 E621 04E9 3395 9011
```

### 2. 比較兩份簽署檔案

```bash
gpg --homedir "$gpg_home" --no-auto-key-retrieve --verify input/dp.src1.asc
echo "exit=$?"
gpg --homedir "$gpg_home" --no-auto-key-retrieve --verify input/dp.src2.asc
echo "exit=$?"
```

`dp.src1.asc` 顯示 `Good signature`，回傳碼為 `0`；`dp.src2.asc` 顯示 `BAD signature`，回傳碼為 `1`。因此第一份檔案的內容與簽章相符。

### 3. 取出原文，再比較兩份獨立簽名

獨立簽名不包含原文，驗證時必須同時提供簽名和被簽署的文字。本次從已通過驗證的 `dp.src1.asc` 取出文字區段，另存為 `output/dp.txt`。

[取出文字的程式](extract-message.py)使用位元組讀寫，保留原文中的空白、CRLF 換行及檔尾換行，不經文字編輯器重新存檔。這支程式針對本題檔案格式，不是通用的 OpenPGP 解析器。

```bash
python extract-message.py
gpg --homedir "$gpg_home" --no-auto-key-retrieve --verify input/dp.src1.sig output/dp.txt
echo "exit=$?"
gpg --homedir "$gpg_home" --no-auto-key-retrieve --verify input/dp.src2.sig output/dp.txt
echo "exit=$?"
```

取出的原文共 555 bytes，SHA-256 為：

```text
7c47d83bad137a1d9535c831f7a32f3cbad2d1e55454707950dfde09a0fbe514
```

## 執行結果

| 小題 | 檔案 | 驗證訊息 | 回傳碼 | 判斷 |
| --- | --- | --- | --- | --- |
| 1 | `dp.src1.asc` | `GOODSIG`、`VALIDSIG` | 0 | 簽章正確 |
| 1 | `dp.src2.asc` | `BADSIG` | 1 | 內容與簽章不符 |
| 2 | `dp.src1.sig` | `CRC error`、`no signature found` | 2 | 簽名檔校驗失敗，無法通過驗證 |
| 2 | `dp.src2.sig` | `GOODSIG`、`VALIDSIG` | 0 | 與取出的原文相符，簽名正確 |

- [完整驗證紀錄](output/verification.txt)：包含四次驗證的訊息、狀態與回傳碼。
- [驗證使用的原文](output/dp.txt)：從第一份簽署檔案取出的 ASCII 字元圖。

## 學習觀察

明文簽署檔案（clear-signed message）把文字和簽章放在同一份檔案；獨立簽名（detached signature）則要搭配原文才能驗證。第二題不能直接拿 `.sig` 去比對整份 `.asc`，因為 `.asc` 還包含標頭與另一份簽章。

本題獨立簽名比對的是原文字元的實際位元組。測試時，將換行改成 LF，或移除最後一個 CRLF，都會讓 `dp.src2.sig` 驗證失敗。因此不能只看畫面上的文字是否相同，也要保留原檔的換行與空白。

`dp.src1.sig` 的 CRC 錯誤與 `dp.src2.asc` 的 `BAD signature` 是不同結果：前者在讀取簽名檔時就發現校驗不符，後者則完成簽章比對後判定不符。本次沒有略過 CRC 檢查或修改簽名檔。

驗證成功時仍會出現金鑰身分未獲信任的警告。本次確認的是簽章與課程提供、且指紋相符的公開金鑰一致；沒有更改信任設定來隱藏警告。
