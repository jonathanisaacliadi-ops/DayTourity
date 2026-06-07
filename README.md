# DayTourity

Platform digital yang menghubungkan wisatawan dengan tour guide lokal terverifikasi secara praktis.

Aplikasi ini berkontribusi terhadap **SDG 8 (Decent Work and Economic Growth)** melalui digitalisasi sektor pariwisata mikro — memberikan standar pendapatan dan pengakuan profesional bagi pemandu lokal sekaligus memperluas akses pasar mereka.

---

### Tampilan Aplikasi

**1. Halaman Login**
![Halaman Login](halaman-login.png)

**2. Halaman Dashboard**
![Halaman Dashboard](halaman-home.png)

---

## Fitur Utama

- **Seamless Booking** — Pemesanan jadwal tur langsung melalui satu platform
- **Advanced Search** — Cari guide berdasarkan lokasi, spesialisasi, dan bahasa
- **Cross-Platform** — Flutter untuk Android dan iOS
- **Detailed Price-view** — Rincian harga per aktivitas pada itinerary

---

## Technology Stack

| Layer | Teknologi |
|---|---|
| Frontend | Flutter (Dart) |
| Backend | NestJS (TypeScript) |
| Database | PostgreSQL (via Supabase) |

---

## Prasyarat

Pastikan tools berikut sudah terinstall sebelum memulai:

- [Node.js](https://nodejs.org/) v18 ke atas
- [Flutter SDK](https://docs.flutter.dev/get-started/install) versi terbaru
- npm (sudah termasuk dalam Node.js)

> Database sudah berjalan di Supabase — tidak perlu setup PostgreSQL lokal.

---

## Instalasi & Menjalankan Backend

### 1. Clone repository

```bash
git clone <repo-url>
cd <nama-folder-backend>
```

### 2. Install dependencies

```bash
npm install
```

### 3. Setup environment

Buat file `.env` di root folder backend, lalu isi dengan nilai berikut:

```dotenv
DATABASE_URL="postgresql://postgres.jxwgixcxctylgsiqirec:LokaGuide132@aws-0-ap-northeast-1.pooler.supabase.com:6543/postgres"
DIRECT_URL="postgresql://postgres.jxwgixcxctylgsiqirec:LokaGuide132@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres"
JWT_SECRET="LokaGuide132"
JWT_EXPIRES_IN="2d"
PORT=3000
```

### 4. Generate Prisma client

```bash
npx prisma generate
```

### 5. Jalankan server

```bash
npm run start:dev
```

Server berjalan di: `http://localhost:3000`

---

## Instalasi & Menjalankan Frontend

### 1. Masuk ke folder frontend

```bash
cd <nama-folder-frontend>
```

### 2. Install dependencies Flutter

```bash
flutter pub get
```

### 3. Pastikan backend sudah berjalan

Frontend perlu terhubung ke backend. Pastikan server NestJS sudah aktif di `http://localhost:3000` sebelum menjalankan aplikasi Flutter.

### 4. Jalankan aplikasi

```bash
flutter run
```

Pilih device atau emulator yang tersedia saat diminta.

> Untuk melihat daftar device yang tersedia: `flutter devices`

---

## Troubleshooting

**`prisma generate` gagal**
Pastikan file `.env` sudah ada dan `DATABASE_URL` terisi dengan benar.

**Flutter tidak bisa connect ke backend**
Pastikan backend sudah berjalan dan base URL di kode Flutter mengarah ke `http://localhost:3000`. Jika menggunakan emulator Android, gunakan `http://10.0.2.2:3000`.

**Port 3000 sudah dipakai**
Ganti nilai `PORT` di `.env` ke port lain (misalnya `3001`), lalu sesuaikan base URL di Flutter.
