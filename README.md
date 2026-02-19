<p align="center">
    <img src="https://raw.githubusercontent.com/ica4me/auto-script-free/main/main_menu.png" width="300"/>
    [Main Menu]
</p>

# 📦 Tutorial Instalasi (Step by Step)

**Rekomendasi OS: Debian 11 / Debian 12 (Stable)**

Panduan ini menjelaskan langkah lengkap instalasi ulang VPS dan
pemasangan auto script secara berurutan hingga siap digunakan.

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
- OS target: Debian 11 / 12 /ubuntu 22.04

---

## ✅ Urutan Instalasi (Wajib Ikuti)

### 0) Reinstall VPS ke Debian 11

Jalankan perintah berikut:

```bash
wget https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && chmod +x reinstall.sh && bash reinstall.sh debian 11 && reboot
```

Tunggu proses selesai → VPS otomatis reboot.

---

### 1) Update Sistem & Install Screen

Login kembali ke VPS setelah reboot, lalu jalankan:

```bash
apt update && apt upgrade -y && apt install -y screen wget curl
```

---

### 2) Buat Swap (Rekomendasi)

Jalankan Jika ram di bawah 4Gb:

```bash
wget https://raw.githubusercontent.com/ica4me/auto-script-free/main/bot/make-swap.sh && chmod +x make-swap.sh && bash make-swap.sh
```

---

### 3) Atur Zona Waktu

Agar waktu server sesuai Indonesia dan selalu sinkron otomatis.

```bash
apt install chrony -y
timedatectl set-timezone Asia/Jakarta
systemctl restart chrony
```

---

### 4) Ubah konfigurasi SSH (Wajib)

```bash
wget -q https://raw.githubusercontent.com/ica4me/auto-script-free/main/kunci-ssh.sh
chmod +x kunci-ssh.sh
./kunci-ssh.sh
```

```bash
wget -q https://raw.githubusercontent.com/ica4me/auto-script-free/main/ubah-ssh.sh
chmod +x ubah-ssh.sh
./ubah-ssh.sh
```

---

### 5) Fix profile environment

```bash
wget -q https://raw.githubusercontent.com/ica4me/auto-script-free/main/fix-profile.sh
chmod +x fix-profile.sh
./fix-profile.sh
```

---

### 6) Install Auto Script setup.sh

Download script installer utama:

```bash
wget https://raw.githubusercontent.com/ica4me/auto-script-free/main/setup.sh
chmod +x setup.sh
screen ./setup.sh
```

Gunakan `screen` agar instalasi tetap berjalan jika SSH terputus.

Tunggu hingga instalasi selesai.

---

### 7) Reset user sistem

```bash
wget -q https://raw.githubusercontent.com/ica4me/auto-script-free/main/reset-user.sh
chmod +x reset-user.sh
./reset-user.sh
```

---

### 8) Reboot VPS (Wajib)

```bash
sed -i 's/\r$//' /usr/local/sbin/m-reboot && m-reboot
```

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
```

---

### ❌ Tidak bisa login SSH setelah ubah port

Cek port baru di script `ubah-ssh.sh`

---

## 📌 Rekomendasi Praktik Aman

✔ Gunakan password kuat\
✔ Aktifkan firewall\
✔ Backup sebelum reinstall\
✔ Simpan konfigurasi penting

---

## 👤 Author / Source

Auto Script:\
https://github.com/ica4me/auto-script-free

Reinstall Script:\
https://github.com/bin456789/reinstall

---

## 📜 Lisensi

GoGreen && Go Free

---

## ⭐ Selesai

Selamat VPS Anda siap digunakan 🚀
