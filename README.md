# APT Mirror Pro

**به فارسی:** ابزار Bash برای عوض کردن **آینهٔ مخازن APT** روی اوبونتو/دبیان، به‌همراه **ابزار DNS** برای تست و انتخاب resolver مناسب توسعه (registryها، Git، بسته‌ها).  
**In English:** A Bash tool to switch Ubuntu/Debian APT mirrors, plus DNS helpers to pick a working resolver for common developer hosts.

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

## فارسی

### چه می‌کند؟
`mirror.sh` یک منوی تعاملی است:

- انتخاب از **۲۸+ آینهٔ از پیش تعریف‌شده**، **Auto** برای پیدا کردن بهترین آینه، **Custom**، و **Manage backups**
- زیرده **DNS tools**: تنظیم/بازگردانی DNS، نمایش وضعیت، تست اتصال، و بنچمارک resolverها

بسته به سیستم، یا `/etc/apt/sources.list` یا `/etc/apt/sources.list.d/ubuntu.sources` (deb822 در اوبونتو ۲۴.۰۴+) نوشته می‌شود. برای DNS از `systemd-resolved` یا `/etc/resolv.conf` پشتیبانی می‌شود.

### نصب و اجرا

**نصب سریع**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/BTF-Kabir-2020/apt-mirror-pro/main/mirror.sh)
```

**نصب دستی (پیشنهادی)**

```bash
git clone https://github.com/BTF-Kabir-2020/apt-mirror-pro.git
cd apt-mirror-pro
chmod +x mirror.sh
sudo ./mirror.sh
```

باید با **root** اجرا شود (`sudo`). در اجرای از روی فایل واقعی، در صورت نبودن، دستور `mirror` به `/usr/local/bin/mirror` وصل می‌شود (اجرای یک‌خطی با `curl` لینک نمی‌سازد).

### گزینه‌های منو

| گزینه | معنی |
|--------|------|
| نام آینه‌ها | فعال‌سازی همان آینه (با اعتبارسنجی) |
| **Auto** | تست موازی latency + سرعت؛ انتخاب بهترین |
| **Official / Regional / Reset / Custom** | مخزن رسمی، آینهٔ کشور، بازگشت، آدرس دلخواه |
| **Show IR list** | لیست آینه‌ها از mirrors.ubuntu.com |
| **Manage backups** | بازگردانی پشتیبان‌های timestamp |
| **DNS tools** | تنظیم DNS، بنچمارک، تست اتصال |
| **Exit** | خروج |

### DNS tools
زیرمنوی DNS شامل presetهای رایج برای محیط توسعه است (گروه‌ها: Developer / ISP / National / Public)، مثلاً Shecan، 403.online، Begzar، Electro، Radar، DynX و چند مورد دیگر، به‌همراه resolverهای عمومی مثل Cloudflare و Google.

- پشتیبان DNS در `/etc/apt-mirror-pro/dns-backups/`
- بنچمارک با `dig` (بستهٔ `dnsutils` در صورت نیاز نصب می‌شود)
- هدف‌های پیش‌فرض بنچمارک/تست: `github.com`، `registry-1.docker.io`، `pypi.org`، `registry.npmjs.org`

سرویس‌های DNS شخص ثالث مستقل‌اند؛ قبل از استفاده در محیط حساس، خودتان بررسی کنید.

### آینه‌های اضافی
لیارا (مسیر جدا برای security) و Amin IDC هم در لیست پیش‌فرض هستند. آینهٔ سفارشی:

`/etc/apt-mirror-pro/custom_mirrors.conf`

```text
نام|https://mirror.example.com/ubuntu/|
نام-split|https://main.example.com/ubuntu/|https://sec.example.com/ubuntu-security/
```

### فایل‌های پیکربندی

| مسیر | کاربرد |
|------|--------|
| `/etc/apt-mirror-pro/custom_mirrors.conf` | آینه‌های اضافه |
| `/etc/apt-mirror-pro/state.env` | آخرین نتیجهٔ Auto |
| `/etc/apt-mirror-pro/backups/` | snapshot کامل قبل از تغییر آینه |
| `/etc/apt-mirror-pro/dns-backups/` | پشتیبان DNS |
| `/etc/apt/sources.list.bak` | پشتیبان اولیه برای Reset |

### پیش‌نیازها
اوبونتو (تمرکز اصلی)، Bash 4+، root، `curl` و در صورت نیاز `dnsutils` (اسکریپت سعی می‌کند نصب کند).

### مشارکت و مجوز
[CONTRIBUTING.md](CONTRIBUTING.md) — مجوز **MIT**: [LICENSE](LICENSE).

---

## English

**APT Mirror Pro** switches Ubuntu/Debian APT mirrors and includes a **DNS tools** submenu for comparing and applying common developer resolvers.

### Features

- 28+ preset mirrors (including Liara split-security and Amin IDC)
- **Auto**: parallel suite + latency + speed probe; apply best
- **deb822** on Ubuntu 24.04+; legacy `sources.list` otherwise
- Backups, snapshots, rollback, custom mirrors
- **DNS tools**: set / restore / status / connectivity test / grouped benchmark
- Safe `mirror` symlink only when run from a real script path (not `bash <(curl …)`)

### DNS tools

Presets are grouped as **Developer**, **ISP**, **National**, and **Public** for package registries and common APIs. Benchmarks need `dig` (`dnsutils`). Third-party DNS services are independent; choose what fits your network and risk model.

Default probe targets: `github.com`, `registry-1.docker.io`, `pypi.org`, `registry.npmjs.org`.

### Install

```bash
git clone https://github.com/BTF-Kabir-2020/apt-mirror-pro.git
cd apt-mirror-pro
chmod +x mirror.sh
sudo ./mirror.sh
```

### License

**MIT** — [LICENSE](LICENSE). [CONTRIBUTING.md](CONTRIBUTING.md).
