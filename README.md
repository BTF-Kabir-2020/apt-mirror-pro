# 🔰 APT Mirror Pro

**به فارسی:** اسکریپت Bash برای عوض کردن **آینهٔ مخازن APT** روی اوبونتو — مخصوصاً وقتی `apt update` کند است یا باید از آینهٔ داخل ایران (مثل اروان) استفاده کنید.  
**In English:** A Bash tool to switch Ubuntu APT mirrors for faster or more reliable `apt` on slow or restricted networks.

![Stars](https://img.shields.io/github/stars/BTF-Kabir-2020/apt-mirror-pro?style=for-the-badge)
![Forks](https://img.shields.io/github/forks/BTF-Kabir-2020/apt-mirror-pro?style=for-the-badge)
![License](https://img.shields.io/github/license/BTF-Kabir-2020/apt-mirror-pro?style=for-the-badge)
![Issues](https://img.shields.io/github/issues/BTF-Kabir-2020/apt-mirror-pro?style=for-the-badge)
![Last Commit](https://img.shields.io/github/last-commit/BTF-Kabir-2020/apt-mirror-pro?style=for-the-badge)
![Repo Size](https://img.shields.io/github/repo-size/BTF-Kabir-2020/apt-mirror-pro?style=for-the-badge)
![Top Language](https://img.shields.io/github/languages/top/BTF-Kabir-2020/apt-mirror-pro?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Debian-E95420?style=for-the-badge&logo=linux&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-Script-121011?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Maintained](https://img.shields.io/badge/Maintained-Yes-brightgreen?style=for-the-badge)

---

## 🇮🇷 راهنمای فارسی

### این برنامه دقیقاً چه می‌کند؟
فایل **`mirror.sh`** منویی باز می‌کند؛ تو یکی از **آینه‌های از پیش تعریف‌شده** (از جمله چند آینهٔ داخل ایران) را انتخاب می‌کنی، یا آدرس دلخواه می‌دهی. اسکریپت فایل **`/etc/apt/sources.list`** را طوری می‌نویسد که APT از همان سرور بسته بگیرد. می‌توانی با گزینهٔ **Auto** سریع‌ترین آینه از لیست را هم امتحان کنی.

### چرا لازم می‌شود؟
در بعضی شبکه‌ها (مثلاً محدودیت دسترسی به سرورهای خارجی یا مسیریابی کند) اوبونتو پیش‌فرض خوب کار نمی‌کند. با عوض کردن آینه به سروری که از **مسیر شما** در دسترس است، معمولاً `apt update` و نصب بسته‌ها راحت‌تر می‌شود.

### نصب و اجرا

**۱) نصب سریع (یک خط، مستقیم از گیت‌هاب)**  
*نیاز داری به اینترنت و آدرس زیر دسترسی داشته باشی؛ فقط از منبعی که به آن اعتماد داری اجرا کن.*

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/BTF-Kabir-2020/apt-mirror-pro/main/mirror.sh)
```

**۲) نصب دستی (امن‌تر — اول کلون، بعد اجرا)**

```bash
git clone https://github.com/BTF-Kabir-2020/apt-mirror-pro.git
cd apt-mirror-pro
chmod +x mirror.sh
sudo ./mirror.sh
```

باید **حتماً با کاربر روت** اجرا شود (`sudo`). اولین باری که با روت اجرا کنی، اگر از قبل نباشد، دستور **`mirror`** در مسیر `/usr/local/bin/mirror` به همین اسکریپت وصل می‌شود؛ بعد می‌توانی بزنی: `sudo mirror`.

### بعد از اجرا چه اتفاقی می‌افتد؟
- یک **پشتیبان یک‌بار** از `sources.list` فعلی گرفته می‌شود (برای گزینهٔ **Reset**).
- روی **اوبونتو ۲۴.۰۴ به بعد** اگر فایل **`ubuntu.sources`** (فرمت جدید deb822) باشد، یک نسخهٔ پشتیبان از آن ذخیره و خود فایل حذف می‌شود تا با `sources.list` جدید **قاطی نشود** (همان مشکلی که قبلاً فقط با ویرایش `sources.list` حل نمی‌شد).
- کش APT پاک و دوباره **`apt update`** اجرا می‌شود.

### گزینه‌های مهم منو (خلاصه)
| گزینه | معنی ساده |
|--------|-----------|
| نام آینه‌ها (مثل ArvanCloud) | همان آینه را روی سیستم فعال می‌کند |
| **Auto** | چند آینه را با `curl` تست می‌کند و سریع‌ترین را برمی‌دارد |
| **Official** | مخازن رسمی اوبونتو (نیاز به دسترسی مناسب به اینترنت جهانی) |
| **Regional** | آینهٔ کشور از روی سرویس `ipapi.co`؛ اگر تشخیص نشود پیش‌فرض **`ir`** می‌شود؛ باز هم به اینترنت جهانی وابسته است |
| **Reset** | برمی‌گرداند به پشتیبان اولیهٔ `sources.list` و در صورت وجود، `ubuntu.sources` را هم برمی‌گرداند |
| **Custom** | خودت آدرس پایهٔ آینه را می‌نویسی |
| **Show IR list** | لیستی از گیت‌هاب اوبونتو می‌گیرد؛ ممکن است بدون اینترنت جهانی باز نشود |

### اینترنت ایران / شبکه ملی
- گزینه‌های **Official**، **Regional** و **Show IR list** معمولاً به سرورهای خارج از ایران یا دامنه‌های جهانی وابسته‌اند.
- برای محیطی که فقط آینهٔ داخلی دارد، از **همان لیست آینه‌های ایران** یا **Auto** استفاده کن (فقط به همان URLهای داخل اسکریپت وصل می‌شود).

### امنیت و بازگشت
- فقط آدرس‌هایی که با `http://` یا `https://` شروع شوند پذیرفته می‌شوند.
- با **Reset** می‌توانی به وضعیت قبل از اولین تغییر (طبق فایل پشتیبان) برگردی.

### پیش‌نیازها
- اوبونتو (تمرکز اصلی روی اوبونتو؛ دبیان شبیه ممکن است کار کند ولی تست deb822 برای اوبونتو است)
- **Bash نسخه ۴ به بالا**
- دسترسی **root** (`sudo`)
- **`curl`** روی سیستم
- **`lsb_release`** اختیاری است؛ اگر نباشد نسخهٔ سیستم از **`/etc/os-release`** خوانده می‌شود

### مشارکت و مجوز
مشارکت در پروژه خوش‌آمد است؛ جزئیات در [CONTRIBUTING.md](CONTRIBUTING.md). مجوز: **MIT** — فایل [LICENSE](LICENSE).

---

## English

**APT Mirror Pro** is a Bash menu-driven utility to switch Ubuntu APT mirrors, speed-test them (**Auto**), use official/regional/custom URLs, and **Reset** to a saved `sources.list`. On **Ubuntu 24.04+** it backs up and removes **`/etc/apt/sources.list.d/ubuntu.sources`** when needed so APT does not merge conflicting deb822 sources with `sources.list`. It runs `apt clean`, clears list cache, then `apt update`. First **root** run may install **`/usr/local/bin/mirror`** pointing at this script.

### Features (short)

- Iranian + official + custom mirrors, **Auto** latency test, **Regional** (ipapi.co, fallback `ir`)
- Backup / **Reset**, deb822 handling, cache refresh, URL validation

### Installation

Quick (trusted source only):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/BTF-Kabir-2020/apt-mirror-pro/main/mirror.sh)
```

Manual:

```bash
git clone https://github.com/BTF-Kabir-2020/apt-mirror-pro.git
cd apt-mirror-pro
chmod +x mirror.sh
sudo ./mirror.sh
```

### How it works (technical)

1. Optional **Auto**: `curl` timing to each mirror’s `dists/<codename>/Release`.  
2. Writes `sources.list` (main, updates, backports, security). Non-official mirrors use the **same base** for `-security`; official layout uses `security.ubuntu.com`.  
3. Ubuntu 24.04+: backup then remove `ubuntu.sources` (restore on **Reset** if backup exists).  
4. `apt clean`, wipe `/var/lib/apt/lists/*`, `apt update`.  
5. Codename: `lsb_release -cs` or `VERSION_CODENAME` from `/etc/os-release`.

### Network

**Official**, **Regional**, and **Show IR list** need public Ubuntu-related endpoints. **Iranian mirrors** + **Auto** only use URLs embedded in the script.

### Requirements

Ubuntu-focused, **Bash 4+**, **root**, **curl**, `lsb_release` optional.

### License & contributing

**MIT** — see [LICENSE](LICENSE). See [CONTRIBUTING.md](CONTRIBUTING.md).

---
