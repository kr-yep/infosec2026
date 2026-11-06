# 2026 資訊安全實務與應用作業

這裡整理「資訊安全實務與應用」的課程作業。

課程進度核對日期：2026-11-06。最新公布至 11/02 的 TLS／SSL 與 SSH 講義。

已核對課程首頁與連結的 20 份文件，目前未找到 HW4、HW5；新增的 Tomcat 與 SSH 練習都標為未編號 Lab。

| 作業 | 內容 | 進度 |
| --- | --- | --- |
| [HW1 資安新聞紀錄](security-news.md) | 閱讀資安新聞，整理摘要與學習觀察 | 10/5 已首次繳交；目前 5 則，最近更新 2026-11-06；每週至少更新 1 則，全學期至少 15 則 |
| [HW2 GPG 簽章驗證與檔案輸出](hw2/README.md) | 驗證老師提供的檔案簽章，取出並展示內容 | 已於 2026-10-05 繳交 |
| [HW3 簽署檔案與獨立簽名驗證](hw3/README.md) | 10/6 題目版本：比較兩份簽署檔案與兩份獨立簽名 | 2026-10-06 完成，已於 2026-10-18 寄送 |
| [GPG 加密、簽署與驗證 Lab](labs/gpg-sign-encrypt/README.md) | 目前講義的加密、簽署與驗證練習 | 四項測試通過，已於 2026-10-18 寄送 |
| [Notepad++ 簽章與憑證 Lab](labs/notepad-signature/README.md) | 10/12 講義：GPG、SHA-256 與憑證信任比較 | 離線 Windows VM 操作與截圖完成，已於 2026-10-18 寄送 |
| [Tomcat 自建 CA 與 HTTPS Lab](labs/tomcat-tls/README.md) | 10/19 講義：憑證簽發、Java keystore 與瀏覽器信任 | VM 實測與 16 張截圖完成，已於 2026-11-06 寄送 |
| [SSH 演算法設定 Lab](labs/ssh-algorithms/README.md) | 11/02 講義：演算法相容性、設定修正與掃描 | VM 實測與 3 張截圖完成，已於 2026-11-06 寄送 |

HW1、HW2、HW3 與先前的 GPG、Notepad++ Lab 已寄送。Tomcat、SSH 兩份新 Lab 也已於 2026-11-06 分別寄送；接下來持續更新 HW1 並確認新作業。

## 講義版本與本次範圍

10/6 讀取的 More GPG examples 原本有 HW3 與兩小題下載檔案；10/18 的同一頁已改為一般 LAB：「加密、簽署檔案」「驗證檔案與簽章」。先前的 HW3 成果照原題保留，目前版本的練習另列為 Lab。

Notepad++ 憑證驗證依 10/12 講義完成。這兩份練習沒有標上新的作業編號，因此沿用講義的 Lab 名稱，不自行編成 HW4。Notepad++ 的憑證操作在離線 Windows 虛擬機內完成，報告保留前後結果與實際截圖。

## 繳交方式

將 HackMD 或 GitHub 作業網址寄到 `cnchen@pu.edu.tw`。依目前確認的繳交格式，信件主旨統一使用 `HW編號 學號`，中間留一個半形空格，例如 `HW1 學號`、`HW2 學號`、`HW3 學號`；內文放該份作業的直接連結。

每份作業分開寄送，主旨只放作業編號與學號。補充的 Lab 連結列在內文。[計分表說明](https://hackmd.io/u32Hk62nR8qMhWIRqqJ2oA)保留供核對。

各份作業統一列出題目來源、進度、作業內容或操作步驟、結果與學習觀察。這是本專區的整理方式；HW1 依每則新聞分段，HW2、HW3 依實作步驟與結果分段。

## 課程來源

- [課程講義與作業要求](https://hackmd.io/@chiounan/infosec2026)
- [老師的資安新聞參考範例](https://hackmd.io/@chiounan/security-news)
- [More GPG examples（目前版本）](https://hackmd.io/b5RNk-hgSwq7NKmQwD80vg)
- [Digital Certificate](https://hackmd.io/hd6MvcxFS0Gb_1WTtsxg_w)
- [Notepad++ 簽章與憑證實驗](https://hackmd.io/WkND2kC1Sz-fJ9lHR87lEQ)
