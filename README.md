# 🔰 APT Mirror Pro

🚀 Lightning-fast APT mirror switcher for Ubuntu & Debian  
⚡ ابزار هوشمند انتخاب سریع‌ترین Mirror برای لینوکس

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

## 🚀 Overview (English)

**APT Mirror Pro** is a smart Bash utility for switching, testing, and optimizing Ubuntu APT mirrors.  
It automatically selects the fastest mirror and improves package download performance in restricted or slow networks.

### ✨ Features

- 🔁 Quick APT mirror switching
- ⚡ Automatic speed testing of mirrors
- 🌍 Best mirror auto‑selection
- 🌍 Full list of regional mirrors (including Iran)
- 🧠 Regional‑based mirror detection
- 💾 Automatic backup of `sources.list`
- 🔐 URL validation for safety
- 🧩 Simple global command: `mirror`

---

## 🇮🇷 معرفی پروژه (Persian)

**APT Mirror Pro** یک ابزار حرفه‌ای Bash برای تغییر، تست و بهینه‌سازی Mirrorهای اوبونتو است.  
این ابزار به صورت خودکار سریع‌ترین سرور را انتخاب کرده و سرعت دانلود پکیج‌ها را در شبکه‌های محدود یا کند افزایش می‌دهد.

### ✨ قابلیت‌ها

- 🔁 تغییر سریع Mirror
- ⚡ تست سرعت خودکار سرورها
- 🌍 انتخاب بهترین Mirror به صورت اتوماتیک
- 🇮🇷 لیست کامل Mirrorهای ایران
- 🧠 تشخیص Region و انتخاب هوشمند
- 💾 بکاپ خودکار از `sources.list`
- 🔐 بررسی امنیت URL
- 🧩 دستور ساده `mirror`

---

## 📊 Why APT Mirror Pro?

در برخی مناطق به دلیل مشکلات مسیریابی شبکه، دانلود پکیج‌های اوبونتو کند یا ناپایدار است.  
این ابزار مشکل را حل می‌کند با:

- Benchmarking mirror servers in real‑time
- Automatically selecting the fastest route
- Reducing `apt update` and `apt install` time significantly

---

## ⚡ Use Cases

- Slow apt update in your country
- Broken or unstable Ubuntu mirrors
- Optimizing CI/CD Linux environments
- Developers working in restricted networks

---

## 🛠️ Installation

### ⚡ Quick Install (Recommended)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/BTF-Kabir-2020/apt-mirror-pro/main/mirror.sh)
```


## 📦 Manual Install

```bash
git clone https://github.com/BTF-Kabir-2020/apt-mirror-pro.git
cd apt-mirror-pro
chmod +x mirror.sh
sudo ./mirror.sh
```

---

## ⚙️ How It Works

1. Scans available mirror servers  
2. Tests response speed of each server  
3. Selects the fastest one automatically  
4. Updates `/etc/apt/sources.list`  
5. Runs `apt update` automatically  

---

## 🌍 Regional Mode

The tool can detect your country and suggest the closest Ubuntu mirror automatically for better performance.

---

## 🔐 Safety Features

- Automatic backup before changes  
- URL validation (http/https only)  
- Easy rollback support  
- Safe replacement of system repositories  

---

## ⚠️ Requirements

- Linux (Ubuntu / Debian based systems)  
- Root access (`sudo` required)  
- `curl` installed  

---

## 📄 License

This project is licensed under the **MIT License**.

---

## 🤝 Contributing

Contributions are welcome 🚀  

1. Fork the repository  
2. Create a new branch  
3. Make your changes  
4. Submit a Pull Request  

---