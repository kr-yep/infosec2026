# HW2 GPG 簽章驗證與檔案輸出

完成日期：2026-10-05。依照[課程講義](https://hackmd.io/NkCXD6syQmCrmFWMiEsaHg)中的「HW2/LAB: Decrypt the signed file」，使用老師提供的公開金鑰處理 `ascii-art.gpg`，成功取得 ASCII 字元圖，並驗證檔案簽章。

## 操作步驟

本次使用 Windows 上 Git for Windows 附帶的 GnuPG 2.4.9，並使用獨立金鑰目錄。以下指令可在 Git Bash 中，於本作業 `hw2` 目錄執行；若已存在同名輸出，GPG 會詢問是否覆寫。

1. 下載題目提供的[簽章檔案](https://github.com/cnchenpu/SysSec-pub/raw/main/sec101/ascii-art.gpg)與[公開金鑰](https://raw.githubusercontent.com/cnchenpu/SysSec-pub/main/sec101/public-key.key)。本專區的 `input/` 保留這兩份原始檔案。
2. 建立獨立金鑰目錄並匯入公開金鑰。

```bash
gpg_home="$(mktemp -d)"
gpg --homedir "$gpg_home" --import input/public-key.key
```

3. 取出檔案內容，同時驗證簽章，接著顯示輸出。

```bash
mkdir -p output
gpg --homedir "$gpg_home" --no-auto-key-retrieve \
  --status-file output/gpg-status.txt \
  --output output/ascii-art.txt --decrypt input/ascii-art.gpg \
  2> output/gpg-verification.txt
cat output/gpg-verification.txt
cat output/ascii-art.txt
```

## 執行結果

本次 GPG 回傳碼為 `0`，輸出檔案共 **4,940 bytes、50 行**。驗證紀錄出現 `GOODSIG` 與 `VALIDSIG`，表示以匯入的公開金鑰驗證簽章成功。

```text
gpg: Good signature from "testid <testid@gmail.com>" [unknown]
Primary key fingerprint: CD5E FDA4 EC66 9CDD 8F5A 7142 0805 311C D398 A20A
```

以下圖片由實際輸出的文字以等寬字型繪製，方便在網頁中觀看；它不是終端機截圖，原始文字未更動。

![GPG 輸出的 ASCII 字元圖](output/ascii-art.png)

- [完整原始文字](output/ascii-art.txt)
- [GPG 驗證訊息與信任警告](output/gpg-verification.txt)
- [機器可讀的簽章狀態](output/gpg-status.txt)
- [封包檢查結果](output/gpg-packets.txt)
- [圖片繪製程式](render-output.ps1)

## 簽章與加密的差別

雖然題目使用 decrypt 一詞，而且操作指令是 `--decrypt`，本次[封包檢查](output/gpg-packets.txt)顯示檔案包含壓縮、one-pass signature、literal data 與 signature 封包，沒有加密資料封包。因此這次是取出帶有簽章的內容並驗證簽章，不需要私鑰或密碼；不能由此推論公開金鑰能解開一般的機密密文。[GnuPG 手冊](https://www.gnupg.org/gph/en/manual.html)的 Making and verifying signatures 一節也說明可用 `--decrypt` 取出文件並驗證其簽章。

驗證同時出現 `TRUST_UNDEFINED` 與「This key is not certified with a trusted signature」警告。這表示目前沒有建立該金鑰與真實身分之間的獨立信任關係，並不等同於簽章比對失敗。本次能確認的是檔案簽章與課程提供的公開金鑰相符；沒有修改金鑰信任設定來隱藏警告。

## 檔案來源與核對

題目正文與 Hint 中的[舊下載連結](https://github.com/cnchenpu/linux-sysadmin-2020/raw/master/ascii-art.gpg)在本次下載時具有相同 SHA-256，因此使用正文的 `SysSec-pub` 版本。

| 檔案 | SHA-256 |
| --- | --- |
| `input/ascii-art.gpg` | `4ce689bade951da87682664903982f48b42f36f812be7e7bcf2d1d0e16832bb2` |
| `input/public-key.key` | `9dab5dbba5e5125569c65cafd5dacdf54e4ade4ead4e5555518009b4c628d79a` |
| `output/ascii-art.txt` | `ba7e93371038750457a9941a0ea36d4dca98a3cd04fa019ea4eff2aa93835ad1` |

簽章中的 2021-04-25 是原始簽署日期；本次作業執行日期是 2026-10-05。此頁完成檔案處理與結果展示，尚未寄信繳交。
