# 📦 README — Tutorial Instalasi Script VPS

**Rekomendasi OS: Debian 11 / Debian 12 (Stable)**

Panduan ini menjelaskan langkah lengkap instalasi ulang VPS dan pemasangan auto script secara berurutan hingga siap digunakan.

---

## ⚠️ PERINGATAN PENTING

- Proses reinstall akan **menghapus seluruh data VPS**
- Backup data penting sebelum melanjutkan
- Gunakan akses **root**
- Pastikan koneksi VPS stabil
- Disarankan VPS kosong / fresh install

---

## 🖥️ Persyaratan

- VPS KVM / VM full virtualization
- RAM minimal 1 GB (rekomendasi 2 GB)
- Akses root SSH
- Internet stabil
- OS target: Debian 11 / 12

---

## 🚀 STEP 1 — Reinstall VPS ke Debian 11

Jalankan perintah berikut:

```bash
wget https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && chmod +x reinstall.sh && bash reinstall.sh debian 11 && reboot
```

Tunggu proses selesai → VPS otomatis reboot.

---

## 🔄 STEP 2 — Update Sistem & Install Screen

Login kembali ke VPS setelah reboot, lalu jalankan:

```bash
apt update && apt upgrade -y && apt install -y screen wget curl
```

---

## Atur Zona Waktu

Agar waktu server sesuai Indonesia dan selalu sinkron otomatis.

```bash
apt install chrony -y
timedatectl set-timezone Asia/Jakarta
systemctl restart chrony
```

---

## 📥 STEP 3 — Install Auto Script

Download script installer utama:

```bash
wget https://raw.githubusercontent.com/ica4me/auto-script-free/main/setup.sh
chmod +x *
screen ./setup.sh
```

Gunakan `screen` agar instalasi tetap berjalan jika SSH terputus.

Tunggu hingga instalasi selesai.

---

## 🔧 STEP 4 — Jalankan Script Tambahan (Fix & Reset)

### 🔁 Ubah konfigurasi SSH

```bash
wget -q https://raw.githubusercontent.com/ica4me/auto-script-free/main/ubah-ssh.sh
chmod +x ubah-ssh.sh
./ubah-ssh.sh
```

---

### 🧩 Fix profile environment

```bash
wget -q https://raw.githubusercontent.com/ica4me/auto-script-free/main/fix-profile.sh
chmod +x fix-profile.sh
./fix-profile.sh
```

---

### 👤 Reset user sistem

```bash
wget -q https://raw.githubusercontent.com/ica4me/auto-script-free/main/reset-user.sh
chmod +x reset-user.sh
./reset-user.sh
```

---

## 🔄 STEP 5 — Reboot VPS (Disarankan)

````bash
sed -i 's/\r$//' /usr/local/sbin/m-reboot && m-reboot```
---

## ✅ Instalasi Selesai

Jika semua langkah berhasil:

- Sistem Debian fresh
- Auto script aktif
- SSH sudah dikonfigurasi
- User sistem sudah reset
- Environment sudah fix

Script siap digunakan.

---

## 🛠️ Troubleshooting

### ❌ Script tidak jalan

Pastikan:

- Login sebagai root
- Internet VPS aktif
- Tidak ada firewall blocking

---

### ❌ Instalasi terputus

Gunakan screen:

```bash
screen -r
````

---

### ❌ Tidak bisa login SSH setelah ubah port

Cek port baru di script `ubah-ssh.sh`

---

## 📌 Rekomendasi Praktik Aman

✔ Gunakan password kuat  
✔ Aktifkan firewall  
✔ Backup sebelum reinstall  
✔ Simpan konfigurasi penting

---

## 👤 Author / Source

Auto Script:  
https://github.com/ica4me/auto-script-free

Reinstall Script:  
https://github.com/bin456789/reinstall

---

## 📜 Lisensi

Gunakan sesuai kebutuhan pribadi / pembelajaran.

---

## ⭐ Selesai

Selamat VPS Anda siap digunakan 🚀
