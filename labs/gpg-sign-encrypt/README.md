# GPG 加密、簽署與驗證實驗

題目來源：[More GPG examples](https://hackmd.io/b5RNk-hgSwq7NKmQwD80vg)底部的 LAB。

進度：2026-10-18 完成實作並寄送。講義目前沒有為這份練習標上作業編號。

## 題目與要求

1. 加密、簽署檔案。
2. 驗證檔案與簽章。

本次使用 Alice、Bob 兩個虛構身分，模擬傳送者與接收者。Alice 使用自己的私鑰簽署檔案，再用 Bob 的公開金鑰加密；Bob 用自己的私鑰解密，再以 Alice 的公開金鑰驗證簽章。另外測試只有公開金鑰及原文被改動的情況。

[返回作業總覽](../../README.md)

## 操作步驟

環境為 Windows、GnuPG 2.4.9 與 Python 3。金鑰使用 Ed25519 簽署、Cv25519 加密，分別建立 Alice、Bob 與驗證者的獨立金鑰目錄。

執行[實驗程式](run-lab.py)：

```bash
python run-lab.py
```

如果 `gpg` 不在 PATH 中，可先把環境變數 `GPG` 設為其執行檔位置。程式依序完成以下操作：

1. 建立實驗用金鑰，互相交換公開金鑰。第三個驗證者只取得 Alice 的公開金鑰。
2. 建立 `message.txt`，用 Alice 的私鑰簽署並加密給 Bob。
3. 由 Bob 解密，確認出現 `GOODSIG`、`VALIDSIG` 和 `DECRYPTION_OKAY`，再逐位元組比較解密檔與原文。
4. 讓只有公開金鑰的驗證者嘗試解密，確認失敗。
5. 另外產生獨立簽名，驗證原文成功，再驗證被修改的原文會失敗。

合併簽署與加密的主要指令如下；兩個指紋由程式從剛建立的金鑰讀取：

```bash
gpg --homedir "$alice_home" --trust-model always \
  --local-user "$alice_fingerprint" --recipient "$bob_fingerprint" \
  --output output/message.gpg --sign --encrypt output/message.txt
gpg --homedir "$bob_home" --output output/decrypted.txt --decrypt output/message.gpg
```

此處 `--trust-model always` 僅用於 Alice 加密給已知的實驗金鑰，不會修改正式金鑰的信任設定。金鑰沒有設定密碼，僅供本次自動化練習；私鑰留在系統暫存目錄，不放進作業專區。

## 執行結果

| 測試 | 回傳碼 | 主要訊息 | 結果 |
| --- | --- | --- | --- |
| Bob 解密並驗證 Alice 的簽章 | 0 | `GOODSIG`、`VALIDSIG`、`DECRYPTION_OKAY` | 成功，解密文字與原文完全相同 |
| 只有公開金鑰的驗證者嘗試解密 | 2 | `NO_SECKEY` | 缺少 Bob 的私鑰，無法解密 |
| 驗證獨立簽名與原文 | 0 | `GOODSIG`、`VALIDSIG` | 成功 |
| 驗證獨立簽名與被修改的文字 | 1 | `BADSIG` | 拒絕被改動的內容 |

- [完整驗證紀錄](output/verification.json)
- [原始文字](output/message.txt)與[解密文字](output/decrypted.txt)
- [加密且帶有簽章的檔案](output/message.gpg)
- [獨立簽名](output/message.sig.asc)
- 實驗用公開金鑰：[Alice](output/alice-public.asc)、[Bob](output/bob-public.asc)

原文與解密檔的 SHA-256 均為：

```text
f5513ae826b9f975c3e31beded9f400c2b90f12e9937fe372c63016e1a3b44c0
```

## 學習觀察

加密和簽章各有用途：Bob 的私鑰決定誰能讀取內容，Alice 的公開金鑰則用來確認簽章是否相符。只有公開金鑰可以驗證簽章，不能因此解開傳給 Bob 的密文。

這次也保留兩個失敗案例。缺少私鑰時，GPG 回報 `NO_SECKEY`；文字被改動時則回報 `BADSIG`。這比只看到一次成功訊息，更能確認操作是否符合預期。這些身分都是實驗建立的，沒有完成真實身分認證。
