# Notepad++ 軟體簽章與憑證驗證實驗

題目來源：[Software Signature and Certificate Example - Notepad++](https://hackmd.io/WkND2kC1Sz-fJ9lHR87lEQ)。

進度：2026-10-18 完成 GPG、SHA-256、內嵌簽章及隔離信任清單的驗證，尚未寄送。講義目前沒有標上作業編號。

## 題目與要求

依講義使用 **Notepad++ 8.8.3**，驗證下載檔案的完整性，檢視程式碼簽章，並比較是否信任 Notepad++ 自簽根憑證時的結果。

本次檢查安裝檔本身，沒有執行安裝程式。講義透過 Windows 的 `certmgr.msc` 安裝及移除根憑證；本次改用 Signify 程式內的隔離信任清單完成比較，沒有執行 Windows 憑證存放區的安裝、移除或 GUI 截圖步驟。以下分別記錄 Windows 原始狀態與隔離驗證結果。

[返回作業總覽](../../README.md)

## 操作步驟

### 1. 下載指定版本與驗證資料

從[官方 v8.8.3 發行頁](https://github.com/notepad-plus-plus/notepad-plus-plus/releases/tag/v8.8.3)下載以下四個檔案，放在 `input/`：

- `npp.8.8.3.Installer.x64.exe`
- `npp.8.8.3.Installer.x64.exe.sig`
- `npp.8.8.3.checksums.sha256`
- `npp.8.8.3.checksums.sha256.sig`

另下載官方的 [GPG 公開金鑰](https://notepad-plus-plus.org/gpg/nppGpgPub.asc)與[自簽根憑證](https://npp-user-manual.org/docs/certs/nppRoot.crt)，保留檔名 `nppGpgPub.asc`、`nppRoot.crt`。

### 2. 驗證 GPG 簽章與 SHA-256

在 Git Bash 中執行：

```bash
gpg_home="$(mktemp -d)"
gpg --homedir "$gpg_home" --import input/nppGpgPub.asc
gpg --homedir "$gpg_home" --no-auto-key-retrieve \
  --verify input/npp.8.8.3.Installer.x64.exe.sig input/npp.8.8.3.Installer.x64.exe
gpg --homedir "$gpg_home" --no-auto-key-retrieve \
  --verify input/npp.8.8.3.checksums.sha256.sig input/npp.8.8.3.checksums.sha256
sha256sum input/npp.8.8.3.Installer.x64.exe
grep 'Installer.x64.exe' input/npp.8.8.3.checksums.sha256
```

本次兩份 GPG 驗證均成功。簽署金鑰的完整指紋為：

```text
14BC E436 2749 B2B5 1F8C 7122 6C42 9F1D 8D84 F46E
```

### 3. 檢視 Windows 簽章與憑證

在 PowerShell 中執行：

```powershell
Get-AuthenticodeSignature input/npp.8.8.3.Installer.x64.exe |
    Format-List Status, StatusMessage, SignerCertificate
```

本次 Windows 回報 `UnknownError`，詳細訊息是「憑證鏈結無法建立於受信任的根授權」。簽署者憑證指紋為 `7F517E235584AFC146F6D3B44CD34C6CC36A3AB2`，與講義列出的值相同。這個結果不能單獨解讀為檔案已遭修改。

### 4. 在隔離信任清單中比較

使用 Python 3、Signify 0.9.3 與 cryptography 50.0.2。可在獨立 Python 環境安裝[指定套件](requirements.txt)，再執行[驗證程式](verify-authenticode.py)：

```bash
python -m pip install -r requirements.txt
python verify-authenticode.py --input input --output output
```

程式先核對根憑證指紋，再驗證三種情況：預設信任清單、額外信任本題根憑證，以及只改動安裝檔第一個 PE section 中一個位元組的負例。變造內容只存在記憶體中，原始下載檔案不會被修改。

Signify 會核對檔案的 Authenticode 摘要、簽章及憑證鏈；相關行為可查閱其[官方文件](https://signify.readthedocs.io/en/latest/authenticode.html)。這次關閉 CRL／OCSP 網路擷取，沒有提供即時撤銷資料，因此結果不包含完整的線上撤銷狀態查驗。

## 執行結果

| 檢查項目 | 結果 |
| --- | --- |
| 安裝檔 GPG 簽章 | `GOODSIG`、`VALIDSIG`，回傳碼 0 |
| 官方 SHA-256 清單的 GPG 簽章 | `GOODSIG`、`VALIDSIG`，回傳碼 0 |
| 安裝檔 SHA-256 | 與已驗證的官方清單完全相符 |
| Windows 預設信任狀態 | 無法建立至受信任根憑證的鏈結 |
| Signify 預設信任清單 | `CERTIFICATE_ERROR` |
| Signify 隔離清單加入本題根憑證 | `OK` |
| 改動 PE section 的一個位元組後 | `INVALID_DIGEST` |

安裝檔 SHA-256：

```text
7094a07167648628e47249a16d9d6db922e5aa1255ac4322a2e4900d233372dd
```

根憑證的 SHA-1 指紋為 `C80539FF7076D22E73A01F164108DAFBF06E45E4`，有效期間是 2025-07-09 至 2055-07-09（臺灣時間），與講義相同。SHA-1 在這裡用來對照憑證指紋，不是本次安裝檔的完整性雜湊。

- [GPG 驗證紀錄](output/gpg-verification.txt)
- [Windows 原始簽章檢查](output/windows-authenticode.json)
- [隔離信任與檔案變造測試](output/authenticode.json)
- [六份下載檔案的大小及 SHA-256](output/download-hashes.json)

## 學習觀察

檔案內容是否符合簽章，以及簽署者是否在信任清單內，需要分開看。這次檔案的 GPG 簽章與 SHA-256 都相符，但舊版的自簽憑證仍無法通過 Windows 預設信任鏈。隔離驗證加入正確的根憑證後，簽章才通過；若改動程式內容，即使信任該根憑證，摘要仍會驗證失敗。

講義最後另有註記：從 v8.8.7 起改用 GlobalSign 簽發的憑證，不再需要安裝舊自簽根憑證，並建議移除先前安裝的根憑證。因此本次將 8.8.3 當作歷史實驗樣本，不把安裝舊根憑證當成日常使用建議。
