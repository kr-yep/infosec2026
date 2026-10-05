# HW1 資安新聞紀錄

課程：[2026 Fall 資訊安全實務與應用](https://hackmd.io/@chiounan/infosec2026)。每週整理資安新聞，記下報導重點與學習觀察，並保留原始來源。

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
