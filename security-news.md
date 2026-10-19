# HW1 資安新聞紀錄

題目來源：[2026 Fall 資訊安全實務與應用](https://hackmd.io/@chiounan/infosec2026)的 HW1: Security News。

進度：持續更新，目前 3 則；最近紀錄日期為 2026-10-19。

## 題目與要求

建立個人 HackMD 或 GitHub 頁面，每週至少整理 1 則資安技術或事件報導，簡述內容並保留來源；全學期至少 15 則。以下依每則新聞列出日期、來源、摘要與學習觀察。

[返回作業總覽與繳交方式](README.md)

## 001 Chrome 桌面版更新修補 32 項安全問題

- 新聞發布日期：2026-09-29
- 紀錄日期：2026-10-05
- 作者與發布單位：Srinivas Sista，Google Chrome
- 原始來源：[Stable Channel Update for Desktop](https://chromereleases.googleblog.com/2026/09/stable-channel-update-for-desktop_01807488085.html)

### 新聞摘要

Google 發布 Chrome 桌面穩定版更新，修補 32 項安全問題。其中包括 ANGLE 元件的緩衝區溢位漏洞 CVE-2026-102331，嚴重度列為 Critical；V8 引擎也有多項列為 High 的型別混淆漏洞。

公告列出的版本為 Windows 與 Mac 的 154.0.8037.92/.93，以及 Linux 的 154.0.8037.92，預計在公告後數天至數週內陸續提供更新。部分漏洞細節會在多數使用者完成更新前限制公開。這份公告沒有提到上述漏洞已被用於實際攻擊。

### 學習觀察

瀏覽器幾乎每天都會用到，安全更新也需要持續留意。這次更新一次修補了 32 項問題，保持更新有助於降低已知漏洞帶來的風險。閱讀這類新聞時，也要分清楚漏洞有多嚴重，以及是否已有人利用它攻擊；只看到 Critical 等級，還不能認定已有受害案例。

## 002 Chrome 155 穩定版更新修補 247 項安全問題

- 新聞發布日期：2026-10-06
- 紀錄日期：2026-10-12
- 作者與發布單位：Daniel Yip，Google Chrome
- 原始來源：[Stable Channel Update for Desktop](https://chromereleases.googleblog.com/2026/10/stable-channel-update-for-desktop_086471744.html)

### 新聞摘要

Google 在 10 月 6 日發布 Chrome 桌面穩定版更新，Windows 與 Mac 更新至 155.0.8059.39/.40，Linux 更新至 155.0.8059.39，並表示將於數天至數週內陸續推出。公告列出 247 項安全修補，包括 Chromecast 的使用後釋放漏洞 CVE-2026-106382，以及 Browser 的使用後釋放漏洞 CVE-2026-106197，兩者皆列為 Critical。官方說明，部分漏洞細節會在多數使用者完成更新前維持限制；公告沒有提到這些漏洞已遭實際攻擊利用。

### 學習觀察

大型軟體更新可能一次修補許多不同元件的問題。使用者應留意穩定版更新並盡快安裝；閱讀漏洞公告時，也要區分嚴重度、修補狀態與實際攻擊證據。這則公告提供漏洞嚴重度與更新資訊，但未說明是否已有受害事件。

## 003 Volexity 揭露 Ivanti Connect Secure 零時差攻擊鏈

- 新聞發布日期：2026-10-13
- 紀錄日期：2026-10-19
- 作者與發布單位：Charlie Gardner、Sean Koessel、Steven Adair 與 Volexity Volcano Team，Volexity
- 原始來源：[A Series of Unauthenticated Events: Chained Exploitation of Ivanti Connect Secure Zero-Days](https://www.volexity.com/blog/2026/10/13/a-series-of-unauthenticated-events-chained-exploitation-of-ivanti-connect-secure-zero-days/)

### 新聞摘要

Volexity 表示，攻擊者在 10 月初利用一組漏洞入侵 Ivanti Connect Secure VPN 設備；調查確認，受害設備當時已更新至 22.8R2.4。攻擊鏈結合認證繞過、遠端程式碼執行與另一項權限提升漏洞，取得未經認證的 root 權限；其中認證繞過與遠端程式碼執行漏洞合併列為 CVE-2026-104935。Volexity 說明，攻擊者曾搜尋並外傳 Active Directory 資料，也利用記憶體修改和清除記錄隱藏活動。Ivanti 於 10 月 13 日釋出 CVE-2026-104935 的修補程式；Volexity 發文時，另一項權限提升漏洞仍待修補。報告也指出，因攻擊者會還原記憶體與設定變更，Ivanti Integrity Checker 可能無法單獨確認設備是否遭入侵。

### 學習觀察

套用已知漏洞的修補程式後，仍要確認攻擊鏈是否包含其他漏洞。這起事件也顯示，檔案完整性檢查可能看不到只在記憶體中發生並被還原的變更；調查時還需檢視網路、記憶體與系統記錄。這是根據 Volexity 調查報告整理的觀察。
