# 🔰 APT Mirror Pro

**به فارسی:** اسکریپت Bash برای عوض کردن **آینهٔ مخازن APT** روی اوبونتو — مخصوصاً وقتی `apt update` کند است یا باید از آینهٔ داخل ایران استفاده کنید.  
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
فایل **`mirror.sh`** یک منوی تعاملی باز می‌کند. می‌توانی یکی از **۲۶+ آینهٔ از پیش تعریف‌شده** (ایران و چند مورد دیگر) را انتخاب کنی، با **Auto** بهترین آینه را پیدا کنی، آدرس **Custom** بدهی، یا از **Manage backups** نسخهٔ قبلی را برگردانی.

اسکریپت بسته به سیستم، یا **`/etc/apt/sources.list`** (legacy) یا **`/etc/apt/sources.list.d/ubuntu.sources`** (deb822 در اوبونتو ۲۴.۰۴+) را می‌نویسد.

### چرا لازم می‌شود؟
در بعضی شبکه‌ها (محدودیت دسترسی به سرورهای خارجی یا مسیریابی کند) اوبونتو پیش‌فرض خوب کار نمی‌کند. با آینهٔ نزدیک‌تر، معمولاً `apt update` و نصب بسته‌ها راحت‌تر می‌شود.

### نصب و اجرا

**۱) نصب سریع (یک خط)**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/BTF-Kabir-2020/apt-mirror-pro/main/mirror.sh)
```

**۲) نصب دستی (امن‌تر)**

```bash
git clone https://github.com/BTF-Kabir-2020/apt-mirror-pro.git
cd apt-mirror-pro
chmod +x mirror.sh
sudo ./mirror.sh
```

باید **با root** اجرا شود (`sudo`). در اولین اجرا، در صورت نبودن قبلی، دستور **`mirror`** به `/usr/local/bin/mirror` وصل می‌شود.

### بعد از اجرا چه اتفاقی می‌افتد؟
- **پشتیبان اولیه** از `sources.list` برای گزینهٔ **Reset** (یک‌بار).
- **پشتیبان با timestamp** در هر تغییر + **snapshot کامل** از `sources.list` و `sources.list.d` در `/etc/apt-mirror-pro/backups/`.
- روی **اوبونتو ۲۴.۰۴+**: اگر `ubuntu.sources` وجود داشته باشد، همان فایل با فرمت **deb822** به‌روز می‌شود (نه حذف ساده). در حالت legacy، `ubuntu.sources` پشتیبان و حذف می‌شود تا تداخل نداشته باشد.
- قبل از `apt update`، در صورت قفل بودن APT صبر می‌کند؛ اگر `apt update` شکست بخورد، می‌توانی snapshot را **rollback** کنی.
- کش APT پاک و **`apt update`** اجرا می‌شود.

### گزینه‌های مهم منو

| گزینه | معنی |
|--------|------|
| نام آینه‌ها | فعال‌سازی همان آینه (با اعتبارسنجی قبل از اعمال) |
| **Auto (smart test)** | تست موازی suiteها + latency + سرعت (~۲ ثانیه برای هر آینه)؛ انتخاب بهترین |
| **Official** | مخازن رسمی (`security.ubuntu.com` برای security) |
| **Regional** | آینهٔ کشور با `ipapi.co` (پیش‌فرض `ir`) |
| **Reset** | بازگشت به پشتیبان اولیه |
| **Custom** | آدرس دلخواه |
| **Show IR list** | لیست آینه‌های ایران از mirrors.ubuntu.com |
| **Manage backups** | لیست و بازگردانی پشتیبان‌های timestamp |
| **Exit** | خروج |

### آینهٔ سفارشی
فایل `/etc/apt-mirror-pro/custom_mirrors.conf` — هر خط:

```text
نام|https://mirror.example.com/ubuntu/|
نام-split|https://main.example.com/ubuntu/|https://sec.example.com/ubuntu-security/
```

ستون سوم (security) اختیاری است. برای **شاتل** از قبل split جدا (`mirror.shatel.ir` + `ubuntu-security`) پیکربندی شده.

### فایل‌های پیکربندی

| مسیر | کاربرد |
|------|--------|
| `/etc/apt-mirror-pro/custom_mirrors.conf` | آینه‌های اضافهٔ شما |
| `/etc/apt-mirror-pro/state.env` | آخرین نتیجهٔ Auto |
| `/etc/apt-mirror-pro/backups/` | snapshot کامل قبل از هر تغییر |
| `/etc/apt/sources.list.bak` | پشتیبان اولیه برای Reset |

### Auto (تست هوشمند آینه)
- برای هر آینه، چهار suite (`main`، `updates`، `backports`، `security`) به‌همراه **latency** و **نمونهٔ سرعت** (۲۵۶KB از `Packages.gz`) **هم‌زمان** بررسی می‌شوند.
- بودجهٔ زمانی هدف: حدود **۲ ثانیه برای هر آینه** (آینهٔ قطع دیگر ده‌ها ثانیه معطل نمی‌کند).
- در حین تست می‌توانی **Enter** بزنی تا آینهٔ فعلی رد شود.
- امتیاز از ترکیب تأخیر و سرعت محاسبه می‌شود؛ سه آینهٔ برتر نمایش داده می‌شود و بهترین اعمال می‌شود.
- اعتبارسنجی عمیق‌تر (`Packages.gz` کامل) فقط **قبل از اعمال** آینه انجام می‌شود، نه در مرحلهٔ Auto.

**تنظیم سرعت تست** (بالای `mirror.sh`):

| متغیر | پیش‌فرض | معنی |
|--------|---------|------|
| `PROBE_MIRROR_MAX` | `2` | بودجهٔ زمانی هدف هر آینه (ثانیه) |
| `PROBE_CONNECT` | `1` | timeout اتصال هر درخواست probe |
| `PROBE_MAX` | `2` | حداکثر زمان هر درخواست curl در probe |
| `PROBE_SPEED_BYTES` | `262144` | حجم نمونه برای اندازه‌گیری سرعت (بایت) |

### اینترنت ایران / شبکه ملی
- **Official**، **Regional** و **Show IR list** به endpointهای جهانی وابسته‌اند.
- **لیست آینه‌های ایران** و **Auto** فقط به URLهای داخل اسکریپت (و custom) وصل می‌شوند.

### امنیت و بازگشت
- فقط URLهای `http://` / `https://` پذیرفته می‌شوند.
- **Reset** → وضعیت اولیه؛ **Manage backups** → هر پشتیبان timestamp؛ پس از شکست `apt update` → rollback از snapshot.

### پیش‌نیازها
- اوبونتو (تمرکز اصلی؛ deb822 برای ۲۴.۰۴+)
- **Bash 4+**، **root** (`sudo`)
- **`curl`** (در صورت نبودن، اسکریپت سعی می‌کند نصب کند)
- **`lsb_release`** اختیاری — در غیر این صورت از `/etc/os-release`

### مشارکت و مجوز
[CONTRIBUTING.md](CONTRIBUTING.md) — مجوز **MIT**: [LICENSE](LICENSE).

---

## English

**APT Mirror Pro** is a menu-driven Bash utility to switch Ubuntu APT mirrors: **26+ preset mirrors**, **fast parallel Auto** (~2s per mirror probe), **deb822** on Ubuntu 24.04+, **backup manager**, **full snapshots with rollback**, and **custom mirror config**.

### Features

- Iranian mirrors (ArvanCloud, IranServer, Shatel split, IUT, Petiak, ITO, Runflare, …)
- **Auto**: parallel probe of all four `InRelease` suites plus latency and a 256KB speed sample (~2s budget per mirror); full `Packages.gz` validation runs only when applying a mirror
- **deb822**: writes `ubuntu.sources` when present; legacy mode uses `sources.list`
- **Shatel split**: separate main and `ubuntu-security` URLs
- **Backups**: initial `.bak` for Reset, timestamped copies, full `sources.list.d` snapshots
- **Custom mirrors**: `/etc/apt-mirror-pro/custom_mirrors.conf`
- **APT lock wait**; optional rollback if `apt update` fails after apply
- **`/usr/local/bin/mirror`** symlink on first root run

### Installation

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/BTF-Kabir-2020/apt-mirror-pro/main/mirror.sh)
```

Or clone, `chmod +x mirror.sh`, `sudo ./mirror.sh`.

### How it works

1. **Auto** (optional): parallel per-mirror probes (~2s each), score by latency + speed, pick the best.
2. **Validate** mirror (`Packages.gz` size) before writing sources.
3. Write **deb822** or **legacy** `sources.list`; non-official mirrors usually use the **same base** for `-security` (except split mirrors like Shatel).
4. `apt clean`, clear `/var/lib/apt/lists/*`, `apt update` (waits for APT locks).
5. Codename from `lsb_release -cs` or `/etc/os-release`.

### Auto probe tuning

At the top of `mirror.sh`: `PROBE_MIRROR_MAX` (default `2`), `PROBE_CONNECT` (`1`), `PROBE_MAX` (`2`), `PROBE_SPEED_BYTES` (`262144`). Lower `PROBE_MAX` for faster scans with slightly less accurate speed readings.

### Network

**Official**, **Regional**, and **Show IR list** need public endpoints. **Iranian mirrors**, **Auto**, and **custom** entries use only configured URLs.

### Requirements

Ubuntu-focused, **Bash 4+**, **root**, **curl** (auto-installed if missing), `lsb_release` optional.

### License & contributing

**MIT** — [LICENSE](LICENSE). [CONTRIBUTING.md](CONTRIBUTING.md).

---
