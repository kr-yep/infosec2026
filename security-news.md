# HW1 資安新聞紀錄

題目來源：[2026 Fall 資訊安全實務與應用](https://hackmd.io/@chiounan/infosec2026)的 HW1: Security News。

進度：持續更新，目前 6 則；最近紀錄日期為 2026-11-09。

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

## 004 PHP 提醒 CVE-2026-115560 的罕見 RCE 路徑

- 新聞發布日期：2026-10-23
- 紀錄日期：2026-10-26
- 發布單位：PHP Security Team
- 原始來源：[Informational advisory: Session upload progress](https://www.php.net/archive/2026.php#2026-10-23-1)

### 新聞摘要

PHP Security Team 提醒，`session.upload_progress` 可能涉及一條罕見的遠端程式碼執行路徑，列為 CVE-2026-115560。依公告所述，這需要多個條件同時成立：應用程式先把 `session.serialize_handler` 設為 `php_binary` 或 `php_serialize`，再於執行時以 `ini_set()` 改成 `php` 並呼叫 `session_start()`，同時仍啟用上傳進度功能。PHP 建議在下一次例行修補版發布前設定 `session.upload_progress.enabled=0`；未在執行時切換序列化處理器的應用程式可維持啟用。完整技術公告預計隨下次版本發布。

### 學習觀察

軟體是否受漏洞影響，有時不只看版本，也要檢查應用程式執行時如何改變設定。這則公告描述的風險需要特定設定組合，不能據此推論所有 PHP 網站都能透過相同路徑受到攻擊。

## 005 Cisco Talos 揭露 VOLTA 竊資程式以 LLM 排定受害者價值

- 新聞發布日期：2026-10-31
- 紀錄日期：2026-11-06
- 作者與發布單位：Ryan Fetterman，Cisco Talos
- 原始來源：[Appraisal by AI: Model-driven victim prioritization in the VOLTA infostealer](https://blog.talosintelligence.com/appraisal-by-ai-model-driven-victim-prioritization-in-the-volta-infostealer/)

### 新聞摘要

Cisco Talos 分析一款會自行刪除的 Windows 竊資程式 VOLTA-AUTODOXER。它竊取瀏覽器密碼、工作階段、付款與加密貨幣錢包等資料，也會利用受害者仍有效的登入工作階段進一步蒐集資訊，再整理成結構化資料交給 LLM，評估受害者可變現的資產並排序。Talos 指出，這個 AI 階段主要替操作者整理情報；程式還會在模型拒答時切換到其他模型。若懷疑遭感染，Talos 建議保留 `%APPDATA%\volta_debug.txt`，因為主程式可能已自行刪除。

### 學習觀察

竊資程式結合 AI，不一定是用來突破防禦；這個案例把 AI 放在竊取之後，協助整理受害者資料並決定優先目標。因此，事故處理除了清除惡意程式，也要保留殘存紀錄、撤銷可能遭竊的工作階段與憑證，並評估哪些帳戶和資料已暴露。這項觀察是依 Talos 報告整理。

## 006 SonicWall 修補可繞過 SAML 與 MFA 的 SSL-VPN 漏洞

- 新聞發布日期：2026-11-06
- 紀錄日期：2026-11-09
- 發布單位：SonicWall Product Security Incident Response Team
- 原始來源：[SonicWall PSIRT Security Advisory SNWLID-2026-0014](https://psirt.global.sonicwall.com/vuln-detail/SNWLID-2026-0014)；核對：[Canadian Centre for Cyber Security 公告](https://www.cyber.gc.ca/en/alerts-advisories/sonicwall-security-advisory-av26-1133)、[卡達國家網路安全局公告](https://www.ncsa.gov.qa/en/media/cybersecurity-advisories/566504)

### 新聞摘要

SonicWall 公布 SonicOS SSL-VPN 的驗證繞過漏洞 CVE-2026-19868。若 SSL-VPN 使用 SAML 登入，持有其他驗證方式有效帳密的使用者可能繞過 SAML 控制，連帶避開由 SAML 強制執行的多因素驗證（MFA）。SonicWall 表示已調查可能遭利用的通報；加拿大網路安全中心記錄此漏洞已遭利用，且指出 CISA 於 11 月 6 日將其列入已知遭利用漏洞（KEV）目錄。此問題只影響啟用 SAML 的 SSL-VPN 登入情境。

### 學習觀察

啟用 MFA 不代表每一條登入路徑都受到同等保護；若同一服務仍接受可繞過 SAML 的其他帳密，整體登入安全仍可能被較弱的路徑限制。檢查遠端存取時，除了確認 MFA 狀態，也應盤點是否存在其他驗證方式。這是根據廠商公告與政府資安單位公告整理的觀察。
