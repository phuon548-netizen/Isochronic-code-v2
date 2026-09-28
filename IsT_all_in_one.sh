#!/bin/bash
# =============================================================================
#  IsT - Isochronic Tones  |  BAN GOP 1 FILE (Android + loi C++)
#  Phien ban dac ta: 1.1 Pro   |  Tat ca ma nguon nam trong file nay.
#
#  CACH DUNG:
#    bash IsT_all_in_one.sh            -> bung ra thu muc ./IsT day du
#    bash IsT_all_in_one.sh /duong/dan -> bung ra thu muc chi dinh
#  Sau khi bung:
#    cd IsT && make test     # chay 85 bai kiem thu loi audio C++ tren may tinh
#    mo thu muc IsT bang Android Studio de build APK
#
#  Ghi chu: file nhi phan (icon PNG, splash) khong nhung duoc vao file text,
#  script se tu sinh lai bang tools/make_logo.py (can Python + Pillow).
# =============================================================================
set -e
DEST="${1:-./IsT}"
mkdir -p "$DEST"
cd "$DEST"
echo "Dang bung ma nguon vao: $(pwd)"


# ----------------------------------------------------------------------------
# FILE: README.md
# ----------------------------------------------------------------------------
cat > 'README.md' <<'IST__EOF__b7f3'
# IsT — Isochronic Tones (bản Android)

Triển khai theo đặc tả **v1.1 Pro**. Nguyên tắc: **lõi audio C++ chính xác tuyệt đối trước, tính năng sau.**

---

## 1. Kết quả kiểm thử lõi audio (đã chạy thật, log ở `tests/test_report.txt`)

**85/85 PASS, lặp lại 3–5 lần đều giống nhau.** Các số đo quan trọng:

| Hạng mục | Kết quả đo được |
|---|---|
| Trôi nhịp sau **2 giờ liên tục** (48 kHz, 10 Hz / 7.5 Hz / 1 Hz) | **0.000 mẫu** — không trôi nhịp |
| Trôi nhịp 2 giờ @44.1 kHz, 40 Hz | 0.5 mẫu (**0.011 ms**, do lượng tử hoá mẫu, không tích luỹ) |
| Jitter đo trên **tín hiệu output thật** (4/10/20 Hz, 295 s) | **0.0000 ms**, tần số đo được 10.000000 Hz |
| Duty cycle | 0.500000 ở mọi tần số 1–40 Hz |
| Envelope raised-cosine 5 ms | sai lệch tối đa so với lý thuyết **3e-8** |
| Carrier | 200.0000 Hz, RMS 0.707107, sai lệch so với sine lý tưởng 3e-7 |
| Ducking | đáy −4 dB (0.6316 vs 0.6310), attack đo được 14.83 ms, điểm đáy luôn nằm trong pha pulse |
| Limiter | không bao giờ vượt −1 dBFS; trong suốt tuyệt đối khi dưới ngưỡng |
| Click/pop | bước nhảy biên độ tối đa 0.0147 suốt 35 phút (không có điểm gián đoạn) |
| Hiệu năng | **708× realtime** trên 1 lõi máy tính → thừa biên cho điện thoại |
| Giới hạn phiên | dừng đúng **2100.000 s** pulse, fade-out 3 s |
| Khoá cứng ngày | cắt đúng tại **2100.000 s** cộng dồn, kể cả khi chạm mốc giữa phiên |
| Chống lách luật | 15 phiên × 5 phút → chỉ 7 phiên chạy, 8 lần bị chặn, tổng đúng 35:00; đổi band vẫn bị khoá |

Nghe thử bằng tai: `demo/demo_10hz_alpha.wav`, `demo/demo_4hz_theta.wav`, `demo/demo_20hz_beta.wav`.

Chạy lại kiểm thử trên máy tính (không cần Android):

```bash
make test      # 85 test
make repeat    # chạy 5 lần liên tiếp
make soak      # soak 2 giờ + render lại file WAV demo
```

---

## 2. Điểm kỹ thuật cốt lõi

- **Phase accumulator bằng số học hữu tỉ nguyên** (`num/den` với `int64`) thay vì cộng dồn số thực → sai số làm tròn **bằng 0**, không trôi nhịp dù chạy nhiều giờ. Đây là thay đổi quan trọng nhất so với cách làm thông thường.
- Toàn bộ pulse / envelope / ducking / limiter / **bộ đếm an toàn** chạy **trong audio callback**, không dùng `Timer`/`sleep()`/`Handler` của OS.
- Ducking **feed-forward**: lấy thẳng envelope pulse đã tính sẵn, không dùng envelope follower → chính xác tuyệt đối, không trễ.
- Output Android: **AAudio** (có sẵn trong NDK, `PERFORMANCE_MODE_LOW_LATENCY`, float 32-bit, buffer = 2 × burst) — không phụ thuộc thư viện ngoài, tự mở lại stream khi đổi thiết bị/route.
- Hai lớp giới hạn 35 phút **độc lập nhau nhưng dùng chung một biến `thoiLuongThucTe`** đúng như đặc tả; thời gian PAUSED và ambient-only không được cộng.

---

## 3. Cấu trúc dự án

```
IsT/
├── core/                        # C++ dùng chung mọi nền tảng (không phụ thuộc Android)
│   ├── include/ist/config.h     # AppConfig - TOÀN BỘ hằng số (mục 10 + 13)
│   ├── include/ist/band.h       # tinhBand() - hàm thuần dùng chung
│   ├── include/ist/dsp.h        # PhaseClock, SineOsc, PulseGate, Ducker, LoopPlayer, Limiter
│   ├── include/ist/session.h    # State machine + 2 lớp giới hạn thời gian
│   ├── include/ist/scoring.h    # Engine random có kiểm soát
│   └── src/*.cpp
├── tests/
│   ├── test_core.cpp            # 85 test (T1..T16)
│   ├── soak_and_render.cpp      # soak 2 giờ + xuất WAV
│   └── test_report.txt          # log chạy thật
├── demo/*.wav                   # file nghe thử
├── brand/                       # logo 1024px, bản đơn sắc, splash
└── app/                         # Android
    ├── build.gradle.kts
    └── src/main/
        ├── cpp/                 # CMakeLists + native_bridge.cpp (JNI + AAudio)
        ├── java/com/personal/ist/
        │   ├── NativeEngine.kt      # binding JNI + hằng số UI
        │   ├── Db.kt                # SQLite: kho, phiên, reject, favorite, bộ đếm ngày/tuần
        │   ├── AudioDecoder.kt      # MediaCodec -> PCM mono float + resample + kiểm tra file
        │   ├── PlaybackService.kt   # Foreground Service + MediaSession + vòng lặp bộ đếm
        │   ├── MainActivity.kt      # Trang chủ / Nghe nhạc / Đang nghe / Giới thiệu an toàn
        │   └── Screens2.kt          # Kho / Lịch sử
        └── res/                 # icon, splash, theme đen–vàng
```

## 4. Build app Android

1. Mở thư mục `IsT/` bằng Android Studio (Giraffe trở lên), cài **NDK + CMake** khi được nhắc.
2. `minSdk 26` (AAudio), `targetSdk 35`, ABI: arm64-v8a + armeabi-v7a.
3. Run → cấp quyền thông báo. Vào **Kho → Lưu thêm âm nền** để thêm file nhạc nền trước khi nghe (engine random cần ít nhất 1 file đúng mức độ mạnh).
4. Khuyến nghị: Cài đặt → Pin → bỏ tối ưu pin cho IsT để Android không treo tiến trình khi khoá màn hình.

> Lưu ý: lớp Kotlin/Android chưa thể biên dịch trong môi trường này (không có Android SDK), nên nó chưa được chạy thử; phần **lõi C++ — thứ quyết định độ chính xác âm thanh — thì đã được biên dịch và kiểm thử thật 85/85**. Lỗi biên dịch vặt phía Kotlin (nếu có) sẽ hiện ngay khi bấm Build lần đầu trong Android Studio.

## 5. Các quyết định đã chốt khi code

| Câu hỏi để ngỏ trong đặc tả | Chốt trong bản này |
|---|---|
| Nền tảng đầu tiên | **Android** (theo yêu cầu), AAudio thay vì Oboe để không phụ thuộc thư viện ngoài |
| Mã màu vàng | **`#D4AF37`** cho logo/UI, `#F2C230` để dành làm màu cảnh báo/khoá |
| `DAILY_BAND_LIMIT_MIN` theo band | Giữ **đồng nhất 35 phút** cho cả 5 band |
| Trang Giới thiệu/An toàn | Hiện **bắt buộc ở lần mở đầu tiên**, có nút "Tôi đã hiểu" (không ép cuộn hết) |
| Ranh giới band | Delta [1,4) · Theta [4,8) · Alpha [8,13) · Beta [13,30) · Gamma [30,40] |
| Khi giới hạn phiên và hạn mức ngày trùng mốc | Ghi lý do `het_gio_phien`, khoá ngày vẫn kích hoạt (qua `evaluateDailyLock`) |

## 6. Còn lại (Giai đoạn 7 của roadmap)

- Export/Import `.istbackup` (nén DB + file audio) — chưa làm.
- Media control trên lock screen đã có MediaSession + notification; chưa thêm artwork.
- Màn hình "Nâng cao" để chỉnh `CARRIER_FREQ_HZ`/`DUCK_AMOUNT_DB` (đặc tả nói để bản sau).
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: Makefile
# ----------------------------------------------------------------------------
cat > 'Makefile' <<'IST__EOF__b7f3'
# Kiểm thử lõi C++ trên máy tính (không cần Android)
CXX ?= g++
FLAGS = -std=c++17 -O2 -Icore/include
SRC = core/src/band.cpp core/src/session.cpp core/src/scoring.cpp

all: build/test_core build/soak

build/test_core: $(SRC) tests/test_core.cpp
	@mkdir -p build
	$(CXX) $(FLAGS) $(SRC) tests/test_core.cpp -o $@

build/soak: $(SRC) tests/soak_and_render.cpp
	@mkdir -p build demo
	$(CXX) $(FLAGS) $(SRC) tests/soak_and_render.cpp -o $@

test: build/test_core
	./build/test_core

soak: build/soak
	./build/soak

# chạy lặp 5 lần để chắc chắn không có sai sót ngẫu nhiên
repeat: build/test_core
	@for i in 1 2 3 4 5; do echo "##### LAN $$i #####"; ./build/test_core | tail -3; done

clean:
	rm -rf build demo/*.wav
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: settings.gradle.kts
# ----------------------------------------------------------------------------
cat > 'settings.gradle.kts' <<'IST__EOF__b7f3'
pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { google(); mavenCentral() }
}
rootProject.name = "IsT"
include(":app")
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: build.gradle.kts
# ----------------------------------------------------------------------------
cat > 'build.gradle.kts' <<'IST__EOF__b7f3'
plugins {
    id("com.android.application") version "8.5.2" apply false
    id("org.jetbrains.kotlin.android") version "2.0.20" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.20" apply false
}
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: gradle.properties
# ----------------------------------------------------------------------------
cat > 'gradle.properties' <<'IST__EOF__b7f3'
org.gradle.jvmargs=-Xmx2048m
android.useAndroidX=true
kotlin.code.style=official
android.nonTransitiveRClass=true
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: app/build.gradle.kts
# ----------------------------------------------------------------------------
mkdir -p "app"
cat > 'app/build.gradle.kts' <<'IST__EOF__b7f3'
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.personal.ist"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.personal.ist"     // bundle id theo dac ta muc 2.1
        minSdk = 26                            // AAudio yeu cau API 26+
        targetSdk = 35
        versionCode = 1
        versionName = "1.1"
        externalNativeBuild {
            cmake { cppFlags += listOf("-std=c++17", "-O3") }
        }
        ndk { abiFilters += listOf("arm64-v8a", "armeabi-v7a") }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        debug { isJniDebuggable = true }
    }

    externalNativeBuild {
        cmake { path = file("src/main/cpp/CMakeLists.txt"); version = "3.22.1" }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true }
    packaging { resources.excludes += "/META-INF/{AL2.0,LGPL2.1}" }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-compose:1.9.2")
    implementation(platform("androidx.compose:compose-bom:2024.09.02"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    debugImplementation("androidx.compose.ui:ui-tooling")
}
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: app/proguard-rules.pro
# ----------------------------------------------------------------------------
mkdir -p "app"
cat > 'app/proguard-rules.pro' <<'IST__EOF__b7f3'
-keep class com.personal.ist.NativeEngine { *; }
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: app/src/main/AndroidManifest.xml
# ----------------------------------------------------------------------------
mkdir -p "app/src/main"
cat > 'app/src/main/AndroidManifest.xml' <<'IST__EOF__b7f3'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Chay nen (chuong 9): Foreground Service loai mediaPlayback -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
    <!-- Khong can INTERNET: app hoat dong 100% offline -->

    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:label="IsT"
        android:supportsRtl="false"
        android:theme="@style/Theme.IsT">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:theme="@style/Theme.IsT.Splash"
            android:launchMode="singleTask"
            android:configChanges="orientation|screenSize|keyboardHidden|uiMode">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <service
            android:name=".PlaybackService"
            android:exported="false"
            android:foregroundServiceType="mediaPlayback" />
    </application>
</manifest>
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: core/include/ist/config.h
# ----------------------------------------------------------------------------
mkdir -p "core/include/ist"
cat > 'core/include/ist/config.h' <<'IST__EOF__b7f3'
// IsT - Isochronic Tones (personal app)
// core/include/ist/config.h
// TOÀN BỘ hằng số tinh chỉnh được gom về đây (mục 10 + 13 của đặc tả).
// Không hard-code các giá trị này ở bất kỳ chỗ nào khác.
#pragma once

#include <cstdint>

namespace ist {

struct AppConfig {
    // ---- Audio engine ----
    double carrierFreqHz      = 200.0;   // CARRIER_FREQ_HZ  (sine thuần)
    double pulseDutyCycle     = 0.5;     // PULSE_DUTY_CYCLE
    double pulseEdgeMs        = 5.0;     // PULSE_EDGE_MS (raised-cosine)
    double sessionFadeSec     = 3.0;     // SESSION_FADE_SEC (cho phép 2..5)
    double loopCrossfadeSec   = 3.0;     // loop tốt
    double loopCrossfadeBadSec= 5.0;     // loop không tốt

    // ---- Mixing ----
    double duckAmountDb       = -4.0;    // DUCK_AMOUNT_DB (đến -6 nếu cần)
    double duckAttackMs       = 15.0;
    double duckReleaseMs      = 60.0;

    // ---- Limiter ----
    double limiterThresholdDb = -1.0;
    double limiterLookaheadMs = 5.0;
    double limiterReleaseMs   = 80.0;

    // ---- Mức âm lượng nội bộ (pre-limiter) ----
    double toneGain           = 0.55;    // biên độ carrier tone
    double bgGainWeak         = 0.18;    // "Yếu"
    double bgGainMedium       = 0.35;    // "Vừa"
    double bgGainStrong       = 0.60;    // "Mạnh"

    // ---- Giới hạn thời gian (chương 7 + 8) ----
    int sessionHardLimitMin   = 35;      // SESSION_HARD_LIMIT_MIN
    int dailyBandLimitMin     = 35;      // DAILY_BAND_LIMIT_MIN
    // DAILY_LOCK_SCOPE = ALL_BANDS  (xem session.h / DailyLock)

    // ---- Engine random (scoring_config) ----
    int    cooldownDays       = 2;
    double heSoPhat           = 5.0;
    double diemHop            = 10.0;
    double diemBinhThuong     = 0.0;
    double diemKhongHop       = -15.0;
    double diemThoiDiemKhop   = 5.0;
    double phatTuChoi         = -50.0;
    int    tuChoiWindowDays   = 3;

    // ---- Hệ thống ----
    int sampleRate            = 48000;   // fallback 44100 do lớp platform quyết định
    int bufferSize            = 256;     // gợi ý, thực tế do Oboe trả về
};

// Cấu hình mặc định toàn cục (đọc-ghi từ lớp UI trước khi start phiên).
AppConfig& defaultConfig();

inline double dbToLin(double db) {
    // 10^(db/20)
    return db <= -200.0 ? 0.0 : __builtin_pow(10.0, db / 20.0);
}

} // namespace ist
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: core/include/ist/band.h
# ----------------------------------------------------------------------------
mkdir -p "core/include/ist"
cat > 'core/include/ist/band.h' <<'IST__EOF__b7f3'
// core/include/ist/band.h
// Hàm thuần tinhBand(tanSoHz) - DÙNG CHUNG cho engine random, lịch sử, khoá cứng ngày.
#pragma once
#include <string>

namespace ist {

enum class Band { Delta = 0, Theta = 1, Alpha = 2, Beta = 3, Gamma = 4, Count = 5 };

// Ranh giới (chuẩn hoá cho v1, biên dưới đóng - biên trên mở):
//   Delta [1, 4)   Theta [4, 8)   Alpha [8, 13)   Beta [13, 30)   Gamma [30, 40]
constexpr double kFreqMinHz  = 1.0;
constexpr double kFreqMaxHz  = 40.0;
constexpr double kFreqStepHz = 0.5;

Band  tinhBand(double tanSoHz);
const char* bandKey(Band b);      // "delta" | "theta" | "alpha" | "beta" | "gamma"
const char* bandName(Band b);     // "Delta" ...
Band  bandFromKey(const std::string& key);

} // namespace ist
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: core/include/ist/dsp.h
# ----------------------------------------------------------------------------
mkdir -p "core/include/ist"
cat > 'core/include/ist/dsp.h' <<'IST__EOF__b7f3'
// core/include/ist/dsp.h
// Khối DSP chạy TRONG audio callback. Không cấp phát bộ nhớ, không khoá, không I/O.
#pragma once

#include <cmath>
#include <cstdint>
#include <vector>
#include <algorithm>

namespace ist {

constexpr double kPi = 3.14159265358979323846;

// -----------------------------------------------------------------------------
// PhaseClock: đồng hồ pha sample-accurate.
// Pha được tính TRỰC TIẾP từ số mẫu tuyệt đối (int64) => sai số KHÔNG tích luỹ
// theo thời gian (khác với kiểu phase += inc rồi wrap, vốn dồn lỗi làm tròn).
// Tuyệt đối không dùng timer/sleep của OS ở đây.
// -----------------------------------------------------------------------------
class PhaseClock {
public:
    // Pha được cộng dồn bằng SỐ HỌC HỮU TỈ NGUYÊN (num/den) => sai số làm tròn
    // đúng bằng 0, không trôi nhịp dù chạy liên tục nhiều giờ.
    //   num = freqHz * 1e6 (làm tròn),  den = sampleRate * 1e6
    void prepare(double sampleRate, double freqHz) {
        sr_ = sampleRate; freq_ = freqHz;
        constexpr double kScale = 1.0e6;
        num_ = static_cast<int64_t>(std::llround(freqHz * kScale));
        den_ = static_cast<int64_t>(std::llround(sampleRate * kScale));
        if (num_ <= 0) num_ = 1;
        if (den_ <= num_) den_ = num_ + 1;
        invDen_ = 1.0 / double(den_);
        acc_ = 0; n_ = 0;
    }
    void reset() { acc_ = 0; n_ = 0; }
    // Pha [0,1) tại mẫu hiện tại (chính xác đến từng mẫu).
    inline double phase() const { return double(acc_) * invDen_; }
    inline void advance() {
        acc_ += num_;
        if (acc_ >= den_) acc_ -= den_;
        ++n_;
    }
    inline int64_t sampleIndex() const { return n_; }
    inline double samplesPerCycle() const { return sr_ / freq_; }
    inline double freq() const { return freq_; }

private:
    double sr_ = 48000.0, freq_ = 10.0, invDen_ = 0.0;
    int64_t num_ = 0, den_ = 1, acc_ = 0, n_ = 0;
};

// -----------------------------------------------------------------------------
// Carrier: sine thuần 200 Hz (mặc định), đọc từ wavetable nội suy tuyến tính.
// -----------------------------------------------------------------------------
class SineOsc {
public:
    static const std::vector<float>& table() {
        static const std::vector<float> t = [] {
            std::vector<float> v(kTableSize + 1);
            for (size_t i = 0; i <= kTableSize; ++i)
                v[i] = static_cast<float>(std::sin(2.0 * kPi * double(i) / double(kTableSize)));
            return v;
        }();
        return t;
    }
    void prepare(double sampleRate, double freqHz) { clock_.prepare(sampleRate, freqHz); }
    void reset() { clock_.reset(); }
    inline float next() {
        const std::vector<float>& t = table();
        double p = clock_.phase() * double(kTableSize);
        size_t i = static_cast<size_t>(p);
        double f = p - double(i);
        float s = static_cast<float>(t[i] * (1.0 - f) + t[i + 1] * f);
        clock_.advance();
        return s;
    }
private:
    static constexpr size_t kTableSize = 4096;
    PhaseClock clock_;
};

// -----------------------------------------------------------------------------
// PulseGate: nhịp isochronic. Duty cycle + envelope raised-cosine (Hann half-window)
// 5ms mỗi cạnh. Trả về hệ số 0..1 cho từng mẫu.
// -----------------------------------------------------------------------------
class PulseGate {
public:
    void prepare(double sampleRate, double freqHz, double duty, double edgeMs) {
        clock_.prepare(sampleRate, freqHz);
        duty_ = std::clamp(duty, 0.01, 0.99);
        cycleSamples_ = sampleRate / freqHz;
        onSamples_ = cycleSamples_ * duty_;
        edgeSamples_ = edgeMs * 0.001 * sampleRate;
        // Nếu pha "bật" quá ngắn (tần số cao) thì co cạnh lại cho vừa.
        if (edgeSamples_ * 2.0 > onSamples_) edgeSamples_ = onSamples_ * 0.5;
    }
    void reset() { clock_.reset(); }

    inline float next() {
        double pos = clock_.phase() * cycleSamples_;   // vị trí trong chu kỳ (số mẫu)
        float env = envelopeAt(pos);
        clock_.advance();
        return env;
    }
    // Giá trị envelope hiện tại mà KHÔNG advance (dùng cho ducking feed-forward).
    inline float peek() const { return envelopeAt(clock_.phase() * cycleSamples_); }
    inline bool gateOpen() const { return (clock_.phase() * cycleSamples_) < onSamples_; }
    inline double onSamples() const { return onSamples_; }
    inline double cycleSamples() const { return cycleSamples_; }
    inline double edgeSamples() const { return edgeSamples_; }
    inline int64_t sampleIndex() const { return clock_.sampleIndex(); }

private:
    inline float envelopeAt(double pos) const {
        if (pos >= onSamples_) return 0.0f;           // nửa "tắt" của chu kỳ
        if (edgeSamples_ <= 0.0) return 1.0f;
        double a = 1.0;
        if (pos < edgeSamples_) a = raisedCos(pos / edgeSamples_);
        double rem = onSamples_ - pos;
        if (rem < edgeSamples_) a = std::min(a, raisedCos(rem / edgeSamples_));
        return static_cast<float>(a);
    }
    // Nửa cửa sổ Hann đi lên: 0 -> 1
    static inline double raisedCos(double x) {
        x = std::clamp(x, 0.0, 1.0);
        return 0.5 - 0.5 * std::cos(kPi * x);
    }
    PhaseClock clock_;
    double duty_ = 0.5, cycleSamples_ = 4800.0, onSamples_ = 2400.0, edgeSamples_ = 240.0;
};

// -----------------------------------------------------------------------------
// Ducker feed-forward: giảm âm nền đúng theo lịch pulse đã tính sẵn (không dùng
// envelope follower => không trễ, không cần phân tích tín hiệu).
// -----------------------------------------------------------------------------
class Ducker {
public:
    void prepare(double sampleRate, double amountDb, double attackMs, double releaseMs) {
        floorGain_ = std::pow(10.0, amountDb / 20.0);
        atk_ = coef(attackMs, sampleRate);
        rel_ = coef(releaseMs, sampleRate);
        g_ = 1.0;
    }
    void reset() { g_ = 1.0; }
    // pulseEnv: envelope pulse hiện tại (0..1) -> duck tỉ lệ theo envelope
    inline float next(float pulseEnv) {
        double target = 1.0 + (floorGain_ - 1.0) * double(pulseEnv);
        double c = (target < g_) ? atk_ : rel_;
        g_ = target + (g_ - target) * c;
        return static_cast<float>(g_);
    }
private:
    static double coef(double ms, double sr) {
        double t = std::max(ms, 0.01) * 0.001;
        return std::exp(-1.0 / (t * sr));   // ~63% sau t giây
    }
    double floorGain_ = 0.63, atk_ = 0.0, rel_ = 0.0, g_ = 1.0;
};

// -----------------------------------------------------------------------------
// LoopPlayer: phát file nền dạng mono float, lặp vô hạn với crossfade equal-power.
// -----------------------------------------------------------------------------
class LoopPlayer {
public:
    // data: PCM mono đã decode & resample về sampleRate của engine.
    void setBuffer(const float* data, size_t frames) {
        data_ = data; n_ = frames; pos_ = 0;
    }
    void prepare(double sampleRate, double crossfadeSec) {
        xf_ = static_cast<size_t>(crossfadeSec * sampleRate);
        if (n_ > 0 && xf_ > n_ / 2) xf_ = n_ / 2;
        pos_ = 0;
    }
    inline bool valid() const { return data_ != nullptr && n_ > 8; }
    inline float next() {
        if (!valid()) return 0.0f;
        float s = data_[pos_];
        size_t xstart = n_ - xf_;
        if (xf_ > 0 && pos_ >= xstart) {
            double t = double(pos_ - xstart) / double(xf_);       // 0..1
            double gOut = std::cos(t * kPi * 0.5);                // equal-power
            double gIn  = std::sin(t * kPi * 0.5);
            s = static_cast<float>(s * gOut + data_[pos_ - xstart] * gIn);
        }
        ++pos_;
        if (pos_ >= n_) pos_ = xf_;   // phần đầu đã được phát trong lúc crossfade
        return s;
    }
    void rewind() { pos_ = 0; }
private:
    const float* data_ = nullptr;
    size_t n_ = 0, pos_ = 0, xf_ = 0;
};

// -----------------------------------------------------------------------------
// Limiter lookahead: ngưỡng -1 dBFS, lookahead 5ms, release 80ms.
// Có hard-clamp cuối cùng để đảm bảo TUYỆT ĐỐI không vượt ngưỡng.
// -----------------------------------------------------------------------------
class Limiter {
public:
    void prepare(double sampleRate, double thresholdDb, double lookaheadMs, double releaseMs) {
        thr_ = std::pow(10.0, thresholdDb / 20.0);
        L_ = std::max<size_t>(1, static_cast<size_t>(lookaheadMs * 0.001 * sampleRate));
        delay_.assign(L_, 0.0f);
        maxq_.assign(L_ + 2, 0);
        qv_.assign(L_ + 2, 0.0f);
        wpos_ = 0; qh_ = 0; qt_ = 0; nIn_ = 0;
        relCoef_ = std::exp(-1.0 / (std::max(releaseMs, 0.01) * 0.001 * sampleRate));
        atkCoef_ = std::exp(-1.0 / (std::max(lookaheadMs / 3.0, 0.01) * 0.001 * sampleRate));
        g_ = 1.0;
        clipped_ = 0;
    }
    void reset() {
        std::fill(delay_.begin(), delay_.end(), 0.0f);
        wpos_ = 0; qh_ = 0; qt_ = 0; nIn_ = 0; g_ = 1.0; clipped_ = 0;
    }
    inline float next(float x) {
        // 1) đẩy vào hàng đợi đơn điệu giảm dần để lấy max trượt trên cửa sổ lookahead
        float a = std::fabs(x);
        while (qt_ != qh_) {
            size_t last = (qt_ + qv_.size() - 1) % qv_.size();
            if (qv_[last] <= a) qt_ = last; else break;
        }
        qv_[qt_] = a; maxq_[qt_] = nIn_; qt_ = (qt_ + 1) % qv_.size();
        // bỏ phần tử ra khỏi cửa sổ
        while (maxq_[qh_] + int64_t(L_) < nIn_) qh_ = (qh_ + 1) % qv_.size();
        float peak = qv_[qh_];

        // 2) gain mục tiêu
        double target = (peak > thr_) ? (thr_ / double(peak)) : 1.0;
        double c = (target < g_) ? atkCoef_ : relCoef_;
        g_ = target + (g_ - target) * c;

        // 3) đường trễ
        float y = delay_[wpos_];
        delay_[wpos_] = x;
        wpos_ = (wpos_ + 1) % delay_.size();
        ++nIn_;

        float out = static_cast<float>(y * g_);
        if (out > thr_)  { out = static_cast<float>(thr_);  ++clipped_; }
        if (out < -thr_) { out = static_cast<float>(-thr_); ++clipped_; }
        return out;
    }
    int64_t hardClipCount() const { return clipped_; }
private:
    double thr_ = 0.891, g_ = 1.0, atkCoef_ = 0.0, relCoef_ = 0.0;
    size_t L_ = 240, wpos_ = 0, qh_ = 0, qt_ = 0;
    int64_t nIn_ = 0, clipped_ = 0;
    std::vector<float> delay_, qv_;
    std::vector<int64_t> maxq_;
};

// -----------------------------------------------------------------------------
// Ramp equal-power dùng cho fade in/out phiên (đường cong căn bậc hai).
// -----------------------------------------------------------------------------
class PowerRamp {
public:
    void setInstant(double v) { cur_ = v; tgt_ = v; steps_ = 0; i_ = 0; }
    void rampTo(double target, double seconds, double sampleRate) {
        tgt_ = target; from_ = cur_;
        steps_ = std::max<int64_t>(1, static_cast<int64_t>(seconds * sampleRate));
        i_ = 0;
    }
    inline bool active() const { return i_ < steps_; }
    inline float next() {
        if (i_ >= steps_) { cur_ = tgt_; return static_cast<float>(cur_); }
        double t = double(++i_) / double(steps_);
        // equal-power: nội suy trên miền công suất rồi lấy căn
        double p = from_ * from_ * (1.0 - t) + tgt_ * tgt_ * t;
        cur_ = std::sqrt(std::max(0.0, p));
        return static_cast<float>(cur_);
    }
    inline float value() const { return static_cast<float>(cur_); }
private:
    double cur_ = 0.0, tgt_ = 0.0, from_ = 0.0;
    int64_t steps_ = 0, i_ = 0;
};

} // namespace ist
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: core/include/ist/session.h
# ----------------------------------------------------------------------------
mkdir -p "core/include/ist"
cat > 'core/include/ist/session.h' <<'IST__EOF__b7f3'
// core/include/ist/session.h
// State machine của một phiên nghe (mục 5.8) + hai lớp giới hạn thời gian độc lập:
//   (1) 35 phút liên tục / phiên            (chương 7)
//   (2) 35 phút cộng dồn / band / ngày      (chương 8) -> khoá TOÀN BỘ chức năng nghe
// Bộ đếm được cập nhật REAL-TIME ngay trong audio thread (mục 9.4).
#pragma once

#include <atomic>
#include <cstdint>
#include "ist/config.h"
#include "ist/band.h"
#include "ist/dsp.h"

namespace ist {

enum class SessionState : int {
    Idle = 0, FadeIn, Playing, Paused, FadeOutToneOnly, AmbientOnly, FadeOut, Ended
};

enum class EndReason : int {
    None = 0,
    HetGioPhien,      // "het_gio_phien"     - chạm giới hạn phiên (hoặc timer người dùng đặt)
    NguoiDungDung,    // "nguoi_dung_dung"
    KhoaCungNgay,     // "khoa_cung_ngay"    - chạm hạn mức ngày/band
    HetAmbient        // kết thúc pha ambient-only của chế độ ngủ
};

const char* endReasonKey(EndReason r);
const char* stateName(SessionState s);

struct SessionParams {
    double  freqHz            = 10.0;  // 1..40, bước 0.5
    double  bgGain            = 0.35;  // theo Yếu/Vừa/Mạnh
    int     plannedSeconds    = 1200;  // <= 35*60, clamp cứng
    int     ambientSeconds    = 0;     // > 0 = bật chế độ ngủ
    bool    loopTot           = true;  // quyết định độ dài crossfade
    int64_t dailyPulseSecondsBefore = 0; // tổng đã nghe CÓ PULSE của band này hôm nay
};

class SessionEngine {
public:
    void prepare(int sampleRate, const AppConfig& cfg);

    // ---- gọi từ UI thread ----
    // Trả false nếu bị khoá cứng ngày (đã đạt hạn mức) -> không được phát.
    bool start(const SessionParams& p);
    void requestPause();
    void requestResume();
    void requestStop();
    // "Không hợp": đổi buffer nền, crossfade mượt, KHÔNG đổi state chính.
    void setBackgroundBuffer(const float* data, size_t frames);

    // ---- gọi từ audio thread ----
    // out: interleaved float, channels kênh. Trả về số frame đã ghi (= frames).
    void process(float* out, int frames, int channels);

    // ---- trạng thái đọc được từ mọi thread ----
    SessionState state()      const { return SessionState(state_.load(std::memory_order_relaxed)); }
    EndReason    endReason()  const { return EndReason(endReason_.load(std::memory_order_relaxed)); }
    bool         finished()   const { return state() == SessionState::Ended || state() == SessionState::Idle; }
    // Thời lượng CÓ PULSE thực tế của phiên (giây) - dùng cho cả lịch sử tuần lẫn bộ đếm ngày.
    double       sessionPulseSeconds() const { return double(pulseSamples_.load(std::memory_order_relaxed)) / sr_; }
    // Tổng cộng dồn ngày của band hiện tại (giây), cập nhật real-time.
    double       dailyPulseSeconds()   const { return double(dailyBeforeSamples_) / sr_ + sessionPulseSeconds(); }
    double       elapsedWallSeconds()  const { return double(wallSamples_.load(std::memory_order_relaxed)) / sr_; }
    Band         band() const { return band_; }
    double       freqHz() const { return p_.freqHz; }

private:
    void beginFadeOut(EndReason r);
    inline void setState(SessionState s) { state_.store(int(s), std::memory_order_relaxed); }

    AppConfig cfg_;
    double sr_ = 48000.0;
    SessionParams p_;
    Band band_ = Band::Alpha;

    SineOsc    carrier_;
    PulseGate  pulse_;
    Ducker     duck_;
    Limiter    lim_;
    LoopPlayer bgA_, bgB_;
    PowerRamp  master_;     // fade in/out toàn phiên
    PowerRamp  toneRamp_;   // fade riêng tone (chế độ ngủ)
    PowerRamp  pauseRamp_;  // micro-fade chống click khi tạm dừng
    PowerRamp  swapRamp_;   // crossfade khi bấm "Không hợp"

    bool usingA_ = true;
    bool swapping_ = false;
    bool pausePending_ = false;
    SessionState prevState_ = SessionState::Playing;

    std::atomic<int> state_{int(SessionState::Idle)};
    std::atomic<int> endReason_{int(EndReason::None)};
    std::atomic<int> cmd_{0};                 // 1=pause 2=resume 3=stop
    std::atomic<int64_t> pulseSamples_{0};    // chỉ tăng khi PULSE đang thực sự phát
    std::atomic<int64_t> wallSamples_{0};     // thời gian phiên (không tính lúc PAUSED)
    int64_t dailyBeforeSamples_ = 0;
    int64_t sessionLimitSamples_ = 0;         // min(planned, 35 phút)
    int64_t dailyLimitSamples_ = 0;
    int64_t ambientSamplesLeft_ = 0;
};

// ---------------------------------------------------------------------------
// DailyLock: lớp khoá cứng theo ngày. Nguồn dữ liệu là tổng thời lượng có pulse
// của TỪNG band trong ngày; chạm ngưỡng ở BẤT KỲ band nào -> khoá toàn bộ.
// ---------------------------------------------------------------------------
struct DailyUsage {
    double seconds[int(Band::Count)] = {0, 0, 0, 0, 0};
};

struct LockStatus {
    bool   locked = false;
    Band   triggerBand = Band::Alpha;
    double secondsUsedOnTrigger = 0.0;
};

LockStatus evaluateDailyLock(const DailyUsage& u, const AppConfig& cfg);

} // namespace ist
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: core/include/ist/scoring.h
# ----------------------------------------------------------------------------
mkdir -p "core/include/ist"
cat > 'core/include/ist/scoring.h' <<'IST__EOF__b7f3'
// core/include/ist/scoring.h
// Engine random có kiểm soát (chương 6): lọc cứng độ mạnh -> loại cứng cooldown
// -> tính điểm -> random có trọng số (roulette wheel).
#pragma once
#include <vector>
#include <string>
#include <cstdint>
#include "ist/config.h"

namespace ist {

enum class Strength { Yeu = 0, Vua = 1, Manh = 2 };
enum class TimeSlot { Sang = 0, Chieu = 1, Dem = 2, BatKy = 3 };

TimeSlot timeSlotFromHour(int hour24);   // 5-11 sáng, 12-17 chiều, còn lại đêm

struct SoundStat {
    int         id = 0;
    std::string ten;
    Strength    doManh = Strength::Vua;
    TimeSlot    thoiDiemPhuHop = TimeSlot::BatKy;
    bool        loopTot = true;
    int         lastPlayedDaysAgo = -1;   // -1 = chưa từng nghe
    int         playsLast7Days = 0;
    int         countHop = 0;             // đếm THEO BAND đang chọn
    int         countBinhThuong = 0;
    int         countKhongHop = 0;
    int         rejectedDaysAgo = -1;     // lần bấm "Không hợp" gần nhất
};

struct Scored {
    int    id;
    double score;
    double weight;
};

struct PickResult {
    bool   ok = false;
    int    chosenId = -1;
    bool   relaxedCooldown = false;   // đã phải nới cooldown xuống 1 ngày
    bool   ignoredCooldown = false;   // đã phải bỏ qua cooldown hoàn toàn
    bool   emptyStrength = false;     // kho rỗng ở mức độ mạnh này
    std::vector<Scored> candidates;
};

double tinhDiem(const SoundStat& s, TimeSlot now, const AppConfig& cfg);

PickResult pickBackground(const std::vector<SoundStat>& all,
                          Strength want,
                          TimeSlot now,
                          const AppConfig& cfg,
                          uint64_t rngSeed,
                          int excludeId = -1);

} // namespace ist
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: core/src/band.cpp
# ----------------------------------------------------------------------------
mkdir -p "core/src"
cat > 'core/src/band.cpp' <<'IST__EOF__b7f3'
#include "ist/band.h"

namespace ist {

Band tinhBand(double f) {
    if (f < 4.0)  return Band::Delta;
    if (f < 8.0)  return Band::Theta;
    if (f < 13.0) return Band::Alpha;
    if (f < 30.0) return Band::Beta;
    return Band::Gamma;
}

const char* bandKey(Band b) {
    switch (b) {
        case Band::Delta: return "delta";
        case Band::Theta: return "theta";
        case Band::Alpha: return "alpha";
        case Band::Beta:  return "beta";
        default:          return "gamma";
    }
}

const char* bandName(Band b) {
    switch (b) {
        case Band::Delta: return "Delta";
        case Band::Theta: return "Theta";
        case Band::Alpha: return "Alpha";
        case Band::Beta:  return "Beta";
        default:          return "Gamma";
    }
}

Band bandFromKey(const std::string& k) {
    if (k == "delta") return Band::Delta;
    if (k == "theta") return Band::Theta;
    if (k == "alpha") return Band::Alpha;
    if (k == "beta")  return Band::Beta;
    return Band::Gamma;
}

} // namespace ist
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: core/src/session.cpp
# ----------------------------------------------------------------------------
mkdir -p "core/src"
cat > 'core/src/session.cpp' <<'IST__EOF__b7f3'
#include "ist/session.h"
#include <algorithm>

namespace ist {

AppConfig& defaultConfig() { static AppConfig c; return c; }

const char* endReasonKey(EndReason r) {
    switch (r) {
        case EndReason::HetGioPhien:   return "het_gio_phien";
        case EndReason::NguoiDungDung: return "nguoi_dung_dung";
        case EndReason::KhoaCungNgay:  return "khoa_cung_ngay";
        case EndReason::HetAmbient:    return "het_gio_phien";
        default:                       return "none";
    }
}

const char* stateName(SessionState s) {
    switch (s) {
        case SessionState::Idle: return "IDLE";
        case SessionState::FadeIn: return "FADE_IN";
        case SessionState::Playing: return "PLAYING";
        case SessionState::Paused: return "PAUSED";
        case SessionState::FadeOutToneOnly: return "FADE_OUT_TONE_ONLY";
        case SessionState::AmbientOnly: return "PLAYING_AMBIENT_ONLY";
        case SessionState::FadeOut: return "FADE_OUT";
        default: return "ENDED";
    }
}

LockStatus evaluateDailyLock(const DailyUsage& u, const AppConfig& cfg) {
    LockStatus s;
    const double limit = cfg.dailyBandLimitMin * 60.0;
    for (int i = 0; i < int(Band::Count); ++i) {
        if (u.seconds[i] >= limit - 1e-9) {   // DAILY_LOCK_SCOPE = ALL_BANDS
            s.locked = true;
            s.triggerBand = Band(i);
            s.secondsUsedOnTrigger = u.seconds[i];
            return s;
        }
    }
    return s;
}

// ---------------------------------------------------------------------------

namespace {
// handoff buffer nền giữa UI thread và audio thread (không khoá)
struct Pending {
    std::atomic<const float*> data{nullptr};
    std::atomic<size_t> frames{0};
    std::atomic<bool> ready{false};
};
Pending g_pending;
}

void SessionEngine::prepare(int sampleRate, const AppConfig& cfg) {
    cfg_ = cfg;
    sr_ = double(sampleRate);
    lim_.prepare(sr_, cfg_.limiterThresholdDb, cfg_.limiterLookaheadMs, cfg_.limiterReleaseMs);
    duck_.prepare(sr_, cfg_.duckAmountDb, cfg_.duckAttackMs, cfg_.duckReleaseMs);
    setState(SessionState::Idle);
}

bool SessionEngine::start(const SessionParams& p) {
    p_ = p;
    band_ = tinhBand(p.freqHz);

    dailyLimitSamples_   = int64_t(cfg_.dailyBandLimitMin * 60.0 * sr_);
    dailyBeforeSamples_  = int64_t(double(p.dailyPulseSecondsBefore) * sr_);
    if (dailyBeforeSamples_ >= dailyLimitSamples_) {
        endReason_.store(int(EndReason::KhoaCungNgay));
        setState(SessionState::Idle);
        return false;                      // đã bị khoá cứng -> không cho phát
    }

    const int planned = std::clamp(p.plannedSeconds, 10, cfg_.sessionHardLimitMin * 60);
    sessionLimitSamples_ = int64_t(double(planned) * sr_);
    ambientSamplesLeft_  = int64_t(double(std::max(0, p.ambientSeconds)) * sr_);

    carrier_.prepare(sr_, cfg_.carrierFreqHz);
    carrier_.reset();
    pulse_.prepare(sr_, p.freqHz, cfg_.pulseDutyCycle, cfg_.pulseEdgeMs);
    pulse_.reset();
    duck_.reset();
    lim_.reset();

    const double xf = p.loopTot ? cfg_.loopCrossfadeSec : cfg_.loopCrossfadeBadSec;
    bgA_.prepare(sr_, xf);
    bgB_.prepare(sr_, xf);
    usingA_ = true; swapping_ = false;

    pulseSamples_.store(0);
    wallSamples_.store(0);
    endReason_.store(int(EndReason::None));
    cmd_.store(0);

    master_.setInstant(0.0);
    master_.rampTo(1.0, cfg_.sessionFadeSec, sr_);
    toneRamp_.setInstant(1.0);
    pauseRamp_.setInstant(1.0);
    swapRamp_.setInstant(0.0);

    setState(SessionState::FadeIn);
    return true;
}

void SessionEngine::requestPause()  { cmd_.store(1, std::memory_order_release); }
void SessionEngine::requestResume() { cmd_.store(2, std::memory_order_release); }
void SessionEngine::requestStop()   { cmd_.store(3, std::memory_order_release); }

void SessionEngine::setBackgroundBuffer(const float* data, size_t frames) {
    if (state() == SessionState::Idle || state() == SessionState::Ended) {
        // nạp trực tiếp trước khi phát
        bgA_.setBuffer(data, frames);
        const double xf = p_.loopTot ? cfg_.loopCrossfadeSec : cfg_.loopCrossfadeBadSec;
        bgA_.prepare(sr_, xf);
        usingA_ = true;
        return;
    }
    g_pending.data.store(data, std::memory_order_relaxed);
    g_pending.frames.store(frames, std::memory_order_relaxed);
    g_pending.ready.store(true, std::memory_order_release);
}

void SessionEngine::beginFadeOut(EndReason r) {
    if (state() == SessionState::FadeOut) return;
    if (endReason_.load() == int(EndReason::None)) endReason_.store(int(r));
    master_.rampTo(0.0, cfg_.sessionFadeSec, sr_);
    setState(SessionState::FadeOut);
}

void SessionEngine::process(float* out, int frames, int channels) {
    // ---- lệnh từ UI thread ----
    int c = cmd_.exchange(0, std::memory_order_acquire);
    SessionState st = state();
    if (c == 1 && (st == SessionState::FadeIn || st == SessionState::Playing ||
                   st == SessionState::AmbientOnly || st == SessionState::FadeOutToneOnly)) {
        pausePending_ = true;
        pauseRamp_.rampTo(0.0, 0.03, sr_);      // micro-fade 30ms chống click
        prevState_ = st;
    } else if (c == 2 && (st == SessionState::Paused)) {
        setState(prevState_);
        pausePending_ = false;
        pauseRamp_.rampTo(1.0, 0.03, sr_);
    } else if (c == 3) {
        if (st == SessionState::Paused || st == SessionState::Idle) {
            endReason_.store(int(EndReason::NguoiDungDung));
            setState(SessionState::Ended);
        } else if (st != SessionState::Ended) {
            endReason_.store(int(EndReason::NguoiDungDung));
            pausePending_ = false;
            pauseRamp_.rampTo(1.0, 0.005, sr_);
            beginFadeOut(EndReason::NguoiDungDung);
        }
    }

    // ---- nhận buffer nền mới ("Không hợp") ----
    if (g_pending.ready.load(std::memory_order_acquire) && !swapping_) {
        const float* d = g_pending.data.load(std::memory_order_relaxed);
        size_t n = g_pending.frames.load(std::memory_order_relaxed);
        g_pending.ready.store(false, std::memory_order_relaxed);
        const double xf = p_.loopTot ? cfg_.loopCrossfadeSec : cfg_.loopCrossfadeBadSec;
        LoopPlayer& dst = usingA_ ? bgB_ : bgA_;
        dst.setBuffer(d, n);
        dst.prepare(sr_, xf);
        swapRamp_.setInstant(0.0);
        swapRamp_.rampTo(1.0, 2.0, sr_);
        swapping_ = true;
    }

    for (int i = 0; i < frames; ++i) {
        st = state();
        float sample = 0.0f;

        if (st != SessionState::Idle && st != SessionState::Ended && st != SessionState::Paused) {
            // ---------- kiểm tra giới hạn (sample-accurate) ----------
            if (st == SessionState::FadeIn || st == SessionState::Playing) {
                int64_t ps = pulseSamples_.load(std::memory_order_relaxed);
                // (1) giới hạn liên tục/phiên (hoặc timer người dùng đặt)
                if (ps >= sessionLimitSamples_) {
                    if (ambientSamplesLeft_ > 0) {
                        toneRamp_.rampTo(0.0, cfg_.sessionFadeSec, sr_);
                        setState(SessionState::FadeOutToneOnly);
                    } else {
                        beginFadeOut(EndReason::HetGioPhien);
                    }
                    st = state();
                }
                // (2) khoá cứng cộng dồn ngày/band - cắt phiên ngay tại sample chạm mốc,
                //     bỏ qua ambient-only. (Nếu hai mốc trùng nhau thì phiên kết thúc vì
                //     hết giờ phiên, còn khoá ngày vẫn được kích hoạt qua evaluateDailyLock.)
                else if (dailyBeforeSamples_ + ps >= dailyLimitSamples_) {
                    beginFadeOut(EndReason::KhoaCungNgay);
                    st = state();
                }
            }

            // ---------- sinh tín hiệu ----------
            float pulseEnv = pulse_.next();
            float carrier  = carrier_.next();
            float toneG    = (st == SessionState::FadeOutToneOnly) ? toneRamp_.next() : toneRamp_.value();
            if (st == SessionState::AmbientOnly) toneG = 0.0f;
            float audiblePulse = pulseEnv * toneG;
            float tone = carrier * audiblePulse * float(cfg_.toneGain);

            float bgOld = (usingA_ ? bgA_.next() : bgB_.next());
            float bg    = bgOld;
            if (swapping_) {
                float bgNew = (usingA_ ? bgB_.next() : bgA_.next());
                float t = swapRamp_.next();
                double gIn = std::sin(double(t) * kPi * 0.5);
                double gOut = std::cos(double(t) * kPi * 0.5);
                bg = float(bgOld * gOut + bgNew * gIn);
                if (!swapRamp_.active()) { usingA_ = !usingA_; swapping_ = false; }
            }
            float duckG = duck_.next(audiblePulse);   // feed-forward, đồng bộ tuyệt đối
            bg *= float(p_.bgGain) * duckG;

            float mix = tone + bg;

            // ---------- fade tổng + micro-fade pause ----------
            float m = master_.next();
            float pg = pauseRamp_.next();
            sample = mix * m * pg;

            // ---------- bộ đếm (chỉ khi thực sự đang phát, KHÔNG tính lúc PAUSED) ----------
            if (!pausePending_ || pauseRamp_.active()) {
                wallSamples_.fetch_add(1, std::memory_order_relaxed);
                // chỉ cộng khi PULSE đang thực sự nghe được và phiên chưa vào fade-out
                if (st == SessionState::FadeIn || st == SessionState::Playing) {
                    pulseSamples_.fetch_add(1, std::memory_order_relaxed);
                }
            }

            // ---------- chuyển state ----------
            if (st == SessionState::FadeIn && !master_.active()) {
                setState(SessionState::Playing);
            } else if (st == SessionState::FadeOutToneOnly && !toneRamp_.active()) {
                setState(SessionState::AmbientOnly);
            } else if (st == SessionState::AmbientOnly) {
                if (--ambientSamplesLeft_ <= 0) beginFadeOut(EndReason::HetAmbient);
            } else if (st == SessionState::FadeOut && !master_.active()) {
                setState(SessionState::Ended);
            }
            if (pausePending_ && !pauseRamp_.active() && pauseRamp_.value() <= 0.0001f) {
                setState(SessionState::Paused);
            }
        }

        float y = lim_.next(sample);
        for (int ch = 0; ch < channels; ++ch) out[i * channels + ch] = y;
    }
}

} // namespace ist
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: core/src/scoring.cpp
# ----------------------------------------------------------------------------
mkdir -p "core/src"
cat > 'core/src/scoring.cpp' <<'IST__EOF__b7f3'
#include "ist/scoring.h"
#include <random>
#include <algorithm>
#include <cmath>

namespace ist {

TimeSlot timeSlotFromHour(int h) {
    if (h >= 5 && h <= 11) return TimeSlot::Sang;
    if (h >= 12 && h <= 17) return TimeSlot::Chieu;
    return TimeSlot::Dem;
}

double tinhDiem(const SoundStat& s, TimeSlot now, const AppConfig& cfg) {
    double diem = s.countHop * cfg.diemHop
                + s.countBinhThuong * cfg.diemBinhThuong
                + s.countKhongHop * cfg.diemKhongHop;

    if (s.thoiDiemPhuHop == now || s.thoiDiemPhuHop == TimeSlot::BatKy)
        diem += (s.thoiDiemPhuHop == now ? cfg.diemThoiDiemKhop : 0.0);

    diem -= double(s.playsLast7Days) * double(s.playsLast7Days) * cfg.heSoPhat;

    if (s.rejectedDaysAgo >= 0 && s.rejectedDaysAgo < cfg.tuChoiWindowDays) {
        double k = double(cfg.tuChoiWindowDays - s.rejectedDaysAgo) / double(cfg.tuChoiWindowDays);
        diem += cfg.phatTuChoi * k;    // giảm tuyến tính về 0 ở ngày thứ tuChoiWindowDays
    }
    return diem;
}

static int rouletteWheel(const std::vector<Scored>& c, std::mt19937_64& rng) {
    double total = 0.0;
    for (const auto& s : c) total += s.weight;
    if (total <= 0.0) return c.empty() ? -1 : c[rng() % c.size()].id;
    std::uniform_real_distribution<double> d(0.0, total);
    double r = d(rng), acc = 0.0;
    for (const auto& s : c) { acc += s.weight; if (r <= acc) return s.id; }
    return c.back().id;
}

PickResult pickBackground(const std::vector<SoundStat>& all, Strength want, TimeSlot now,
                          const AppConfig& cfg, uint64_t rngSeed, int excludeId) {
    PickResult res;
    std::mt19937_64 rng(rngSeed);

    // --- Bước 1: lọc cứng theo độ mạnh (không tự đổi mức nếu rỗng) ---
    std::vector<const SoundStat*> byStrength;
    for (const auto& s : all)
        if (s.doManh == want && s.id != excludeId) byStrength.push_back(&s);
    if (byStrength.empty()) { res.emptyStrength = true; return res; }

    // --- Bước 2: loại cứng theo cooldown (trước khi tính điểm) ---
    auto filterCooldown = [&](int days) {
        std::vector<const SoundStat*> v;
        for (auto* s : byStrength)
            if (s->lastPlayedDaysAgo < 0 || s->lastPlayedDaysAgo >= days) v.push_back(s);
        return v;
    };
    std::vector<const SoundStat*> pool = filterCooldown(cfg.cooldownDays);
    if (pool.empty()) { pool = filterCooldown(1); res.relaxedCooldown = true; }   // nới 1 ngày
    if (pool.empty()) { pool = byStrength; res.ignoredCooldown = true; res.relaxedCooldown = false; }

    // --- Bước 3: tính điểm ---
    double minScore = 1e300;
    for (auto* s : pool) {
        Scored sc{s->id, tinhDiem(*s, now, cfg), 0.0};
        minScore = std::min(minScore, sc.score);
        res.candidates.push_back(sc);
    }
    // --- Bước 4: chuẩn hoá về dương + roulette wheel ---
    for (auto& sc : res.candidates) sc.weight = sc.score - minScore + 1.0;

    res.chosenId = rouletteWheel(res.candidates, rng);
    res.ok = res.chosenId >= 0;
    return res;
}

} // namespace ist
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: app/src/main/cpp/CMakeLists.txt
# ----------------------------------------------------------------------------
mkdir -p "app/src/main/cpp"
cat > 'app/src/main/cpp/CMakeLists.txt' <<'IST__EOF__b7f3'
cmake_minimum_required(VERSION 3.22.1)
project(ist)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -ffast-math -fno-finite-math-only")

set(CORE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../../../core)

add_library(ist SHARED
        native_bridge.cpp
        ${CORE_DIR}/src/band.cpp
        ${CORE_DIR}/src/session.cpp
        ${CORE_DIR}/src/scoring.cpp)

target_include_directories(ist PRIVATE ${CORE_DIR}/include)

# AAudio nằm sẵn trong NDK (API 26+), không cần thư viện ngoài.
find_library(log-lib log)
find_library(aaudio-lib aaudio)
target_link_libraries(ist ${log-lib} ${aaudio-lib})
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: app/src/main/cpp/native_bridge.cpp
# ----------------------------------------------------------------------------
mkdir -p "app/src/main/cpp"
cat > 'app/src/main/cpp/native_bridge.cpp' <<'IST__EOF__b7f3'
// app/src/main/cpp/native_bridge.cpp
// Cầu nối JNI + output AAudio (low-latency, có sẵn trong NDK, không cần thư viện ngoài).
// Toàn bộ sinh sóng / envelope / ducking / limiter / bộ đếm an toàn nằm trong
// SessionEngine (C++ dùng chung, đã được kiểm thử ở tests/test_core.cpp).
#include <jni.h>
#include <aaudio/AAudio.h>
#include <android/log.h>
#include <atomic>
#include <mutex>
#include <vector>
#include <memory>
#include <thread>

#include "ist/session.h"
#include "ist/scoring.h"

#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, "IsT", __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "IsT", __VA_ARGS__)

using namespace ist;

namespace {

struct Player {
    AAudioStream* stream = nullptr;
    SessionEngine engine;
    AppConfig cfg;
    int sampleRate = 48000;
    int channels = 2;
    std::mutex bufMutex;
    std::vector<float> bgCurrent;   // buffer nền đang dùng (native sở hữu)
    std::vector<float> bgPending;   // buffer nền mới (chờ crossfade)
    std::atomic<bool> streamOk{false};
};

Player* g = nullptr;

aaudio_data_callback_result_t dataCallback(AAudioStream*, void* user, void* audioData, int32_t numFrames) {
    Player* p = static_cast<Player*>(user);
    p->engine.process(static_cast<float*>(audioData), numFrames, p->channels);
    return AAUDIO_CALLBACK_RESULT_CONTINUE;
}

void errorCallback(AAudioStream*, void* user, aaudio_result_t error);

bool openStream(Player* p) {
    AAudioStreamBuilder* b = nullptr;
    if (AAudio_createStreamBuilder(&b) != AAUDIO_OK) return false;
    AAudioStreamBuilder_setDirection(b, AAUDIO_DIRECTION_OUTPUT);
    AAudioStreamBuilder_setFormat(b, AAUDIO_FORMAT_PCM_FLOAT);
    AAudioStreamBuilder_setChannelCount(b, 2);
    AAudioStreamBuilder_setPerformanceMode(b, AAUDIO_PERFORMANCE_MODE_LOW_LATENCY);
    AAudioStreamBuilder_setSharingMode(b, AAUDIO_SHARING_MODE_SHARED);
    AAudioStreamBuilder_setUsage(b, AAUDIO_USAGE_MEDIA);
    AAudioStreamBuilder_setContentType(b, AAUDIO_CONTENT_TYPE_MUSIC);
    AAudioStreamBuilder_setDataCallback(b, dataCallback, p);
    AAudioStreamBuilder_setErrorCallback(b, errorCallback, p);
    aaudio_result_t r = AAudioStreamBuilder_openStream(b, &p->stream);
    AAudioStreamBuilder_delete(b);
    if (r != AAUDIO_OK) { LOGE("openStream fail: %s", AAudio_convertResultToText(r)); return false; }

    p->sampleRate = AAudioStream_getSampleRate(p->stream);       // 48000 hoặc fallback 44100
    p->channels   = AAudioStream_getChannelCount(p->stream);
    int burst = AAudioStream_getFramesPerBurst(p->stream);
    AAudioStream_setBufferSizeInFrames(p->stream, burst * 2);    // đệm nhỏ nhất còn ổn định
    p->cfg.sampleRate = p->sampleRate;
    p->cfg.bufferSize = burst;
    p->engine.prepare(p->sampleRate, p->cfg);
    LOGI("AAudio: sr=%d ch=%d burst=%d", p->sampleRate, p->channels, burst);
    AAudioStream_requestStart(p->stream);
    p->streamOk = true;
    return true;
}

void closeStream(Player* p) {
    if (p->stream) {
        AAudioStream_requestStop(p->stream);
        AAudioStream_close(p->stream);
        p->stream = nullptr;
    }
    p->streamOk = false;
}

void errorCallback(AAudioStream*, void* user, aaudio_result_t error) {
    // Thiết bị bị rút/đổi route -> mở lại stream, giữ nguyên state machine & bộ đếm.
    Player* p = static_cast<Player*>(user);
    LOGE("AAudio error %s -> reopen", AAudio_convertResultToText(error));
    std::thread([p] {
        closeStream(p);
        openStream(p);
    }).detach();
}

std::vector<float> jfloatsToVec(JNIEnv* env, jfloatArray a) {
    jsize n = env->GetArrayLength(a);
    std::vector<float> v(n);
    env->GetFloatArrayRegion(a, 0, n, v.data());
    return v;
}

std::string jstr(JNIEnv* env, jstring s) {
    if (!s) return "";
    const char* c = env->GetStringUTFChars(s, nullptr);
    std::string r(c ? c : "");
    if (c) env->ReleaseStringUTFChars(s, c);
    return r;
}

} // namespace

extern "C" {

JNIEXPORT jboolean JNICALL
Java_com_personal_ist_NativeEngine_nativeInit(JNIEnv*, jobject) {
    if (!g) g = new Player();
    if (g->streamOk) return JNI_TRUE;
    return openStream(g) ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL
Java_com_personal_ist_NativeEngine_nativeRelease(JNIEnv*, jobject) {
    if (!g) return;
    closeStream(g);
    delete g; g = nullptr;
}

JNIEXPORT jint JNICALL
Java_com_personal_ist_NativeEngine_nativeSampleRate(JNIEnv*, jobject) {
    return g ? g->sampleRate : 0;
}

// PCM mono đã resample sẵn về sampleRate của engine (làm ở Kotlin: AudioDecoder.kt)
JNIEXPORT void JNICALL
Java_com_personal_ist_NativeEngine_nativeSetBackground(JNIEnv* env, jobject, jfloatArray pcm) {
    if (!g) return;
    std::lock_guard<std::mutex> lk(g->bufMutex);
    SessionState st = g->engine.state();
    if (st == SessionState::Idle || st == SessionState::Ended) {
        g->bgCurrent = jfloatsToVec(env, pcm);
        g->engine.setBackgroundBuffer(g->bgCurrent.data(), g->bgCurrent.size());
    } else {
        g->bgPending = jfloatsToVec(env, pcm);     // giữ sống buffer cũ trong lúc crossfade
        g->engine.setBackgroundBuffer(g->bgPending.data(), g->bgPending.size());
        g->bgCurrent.swap(g->bgPending);           // buffer cũ nằm ở bgPending, chưa bị giải phóng
    }
}

JNIEXPORT jboolean JNICALL
Java_com_personal_ist_NativeEngine_nativeStart(JNIEnv*, jobject, jdouble freqHz, jdouble bgGain,
                                               jint plannedSec, jint ambientSec, jboolean loopTot,
                                               jint dailyBeforeSec) {
    if (!g || !g->streamOk) return JNI_FALSE;
    SessionParams p;
    p.freqHz = freqHz;
    p.bgGain = bgGain;
    p.plannedSeconds = plannedSec;
    p.ambientSeconds = ambientSec;
    p.loopTot = (loopTot == JNI_TRUE);
    p.dailyPulseSecondsBefore = dailyBeforeSec;
    return g->engine.start(p) ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL Java_com_personal_ist_NativeEngine_nativePause(JNIEnv*, jobject)  { if (g) g->engine.requestPause(); }
JNIEXPORT void JNICALL Java_com_personal_ist_NativeEngine_nativeResume(JNIEnv*, jobject) { if (g) g->engine.requestResume(); }
JNIEXPORT void JNICALL Java_com_personal_ist_NativeEngine_nativeStop(JNIEnv*, jobject)   { if (g) g->engine.requestStop(); }

JNIEXPORT jint JNICALL Java_com_personal_ist_NativeEngine_nativeState(JNIEnv*, jobject) {
    return g ? (jint)g->engine.state() : 0;
}
JNIEXPORT jint JNICALL Java_com_personal_ist_NativeEngine_nativeEndReason(JNIEnv*, jobject) {
    return g ? (jint)g->engine.endReason() : 0;
}
JNIEXPORT jdouble JNICALL Java_com_personal_ist_NativeEngine_nativePulseSeconds(JNIEnv*, jobject) {
    return g ? g->engine.sessionPulseSeconds() : 0.0;
}
JNIEXPORT jdouble JNICALL Java_com_personal_ist_NativeEngine_nativeDailySeconds(JNIEnv*, jobject) {
    return g ? g->engine.dailyPulseSeconds() : 0.0;
}
JNIEXPORT jint JNICALL Java_com_personal_ist_NativeEngine_nativeBandOf(JNIEnv*, jobject, jdouble hz) {
    return (jint)tinhBand(hz);
}
JNIEXPORT jstring JNICALL Java_com_personal_ist_NativeEngine_nativeBandName(JNIEnv* env, jobject, jint b) {
    return env->NewStringUTF(bandName((Band)b));
}
JNIEXPORT jstring JNICALL Java_com_personal_ist_NativeEngine_nativeEndReasonKey(JNIEnv* env, jobject, jint r) {
    return env->NewStringUTF(endReasonKey((EndReason)r));
}

// ---- Engine random có kiểm soát (chương 6) chạy bằng C++ dùng chung ----
// Trả về: [chosenId, relaxedCooldown, ignoredCooldown, emptyStrength]
JNIEXPORT jintArray JNICALL
Java_com_personal_ist_NativeEngine_nativePick(JNIEnv* env, jobject,
        jintArray ids, jintArray strengths, jintArray slots, jintArray lastPlayed,
        jintArray plays7, jintArray hop, jintArray binhThuong, jintArray khongHop,
        jintArray rejected, jint wantStrength, jint nowSlot, jlong seed, jint excludeId) {
    jsize n = env->GetArrayLength(ids);
    std::vector<jint> vi(n), vs(n), vt(n), vl(n), vp(n), vh(n), vb(n), vk(n), vr(n);
    env->GetIntArrayRegion(ids, 0, n, vi.data());
    env->GetIntArrayRegion(strengths, 0, n, vs.data());
    env->GetIntArrayRegion(slots, 0, n, vt.data());
    env->GetIntArrayRegion(lastPlayed, 0, n, vl.data());
    env->GetIntArrayRegion(plays7, 0, n, vp.data());
    env->GetIntArrayRegion(hop, 0, n, vh.data());
    env->GetIntArrayRegion(binhThuong, 0, n, vb.data());
    env->GetIntArrayRegion(khongHop, 0, n, vk.data());
    env->GetIntArrayRegion(rejected, 0, n, vr.data());

    std::vector<SoundStat> all(n);
    for (jsize i = 0; i < n; ++i) {
        all[i].id = vi[i];
        all[i].doManh = (Strength)vs[i];
        all[i].thoiDiemPhuHop = (TimeSlot)vt[i];
        all[i].lastPlayedDaysAgo = vl[i];
        all[i].playsLast7Days = vp[i];
        all[i].countHop = vh[i];
        all[i].countBinhThuong = vb[i];
        all[i].countKhongHop = vk[i];
        all[i].rejectedDaysAgo = vr[i];
    }
    AppConfig cfg = g ? g->cfg : AppConfig();
    PickResult r = pickBackground(all, (Strength)wantStrength, (TimeSlot)nowSlot, cfg,
                                  (uint64_t)seed, excludeId);
    jint out[4] = { r.ok ? r.chosenId : -1, r.relaxedCooldown, r.ignoredCooldown, r.emptyStrength };
    jintArray res = env->NewIntArray(4);
    env->SetIntArrayRegion(res, 0, 4, out);
    return res;
}

} // extern "C"
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: app/src/main/java/com/personal/ist/NativeEngine.kt
# ----------------------------------------------------------------------------
mkdir -p "app/src/main/java/com/personal/ist"
cat > 'app/src/main/java/com/personal/ist/NativeEngine.kt' <<'IST__EOF__b7f3'
package com.personal.ist

/** Cầu nối tới audio engine C++ (đã kiểm thử ở core/tests). */
object NativeEngine {
    init { System.loadLibrary("ist") }

    external fun nativeInit(): Boolean
    external fun nativeRelease()
    external fun nativeSampleRate(): Int
    external fun nativeSetBackground(pcmMono: FloatArray)
    external fun nativeStart(
        freqHz: Double, bgGain: Double, plannedSec: Int, ambientSec: Int,
        loopTot: Boolean, dailyBeforeSec: Int
    ): Boolean
    external fun nativePause()
    external fun nativeResume()
    external fun nativeStop()
    external fun nativeState(): Int
    external fun nativeEndReason(): Int
    external fun nativePulseSeconds(): Double
    external fun nativeDailySeconds(): Double
    external fun nativeBandOf(hz: Double): Int
    external fun nativeBandName(band: Int): String
    external fun nativeEndReasonKey(reason: Int): String
    external fun nativePick(
        ids: IntArray, strengths: IntArray, slots: IntArray, lastPlayed: IntArray,
        plays7: IntArray, hop: IntArray, binhThuong: IntArray, khongHop: IntArray,
        rejected: IntArray, wantStrength: Int, nowSlot: Int, seed: Long, excludeId: Int
    ): IntArray

    // Trạng thái (khớp enum SessionState bên C++)
    const val IDLE = 0; const val FADE_IN = 1; const val PLAYING = 2; const val PAUSED = 3
    const val FADE_OUT_TONE_ONLY = 4; const val AMBIENT_ONLY = 5; const val FADE_OUT = 6; const val ENDED = 7

    // Lý do kết thúc (khớp enum EndReason)
    const val R_NONE = 0; const val R_HET_GIO_PHIEN = 1; const val R_NGUOI_DUNG_DUNG = 2
    const val R_KHOA_CUNG_NGAY = 3; const val R_HET_AMBIENT = 4

    fun isActive(state: Int) = state != IDLE && state != ENDED
}

object Const {
    const val SESSION_HARD_LIMIT_MIN = 35      // chương 7 - KHÔNG được vượt qua UI
    const val DAILY_BAND_LIMIT_MIN = 35        // chương 8 - KHÔNG được vượt qua UI
    const val DAILY_BAND_LIMIT_SEC = DAILY_BAND_LIMIT_MIN * 60
    val BAND_NAMES = arrayOf("Delta", "Theta", "Alpha", "Beta", "Gamma")
    val STRENGTH_NAMES = arrayOf("Yếu", "Vừa", "Mạnh")
    val SLOT_NAMES = arrayOf("Sáng", "Chiều", "Đêm", "Bất kỳ")
    fun bandOf(hz: Double) = when {
        hz < 4.0 -> 0; hz < 8.0 -> 1; hz < 13.0 -> 2; hz < 30.0 -> 3; else -> 4
    }
    fun bgGain(strength: Int) = when (strength) { 0 -> 0.18; 1 -> 0.35; else -> 0.60 }
    fun fmt(sec: Double): String {
        val s = sec.toInt(); return "%02d:%02d".format(s / 60, s % 60)
    }
    fun fmtLong(sec: Double): String {
        val s = sec.toInt(); return "%02d:%02d:%02d".format(s / 3600, (s % 3600) / 60, s % 60)
    }
}
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: app/src/main/java/com/personal/ist/Db.kt
# ----------------------------------------------------------------------------
mkdir -p "app/src/main/java/com/personal/ist"
cat > 'app/src/main/java/com/personal/ist/Db.kt' <<'IST__EOF__b7f3'
package com.personal.ist

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.util.Calendar

data class Sound(
    val id: Int, val ten: String, val uri: String, val doManh: Int, val loai: String,
    val thoiDiem: Int, val coLoi: Boolean, val loopTot: Boolean, val doDaiSec: Double
)

data class SessionRow(
    val id: Long, val batDau: Long, val tanSo: Double, val band: Int, val doManh: Int,
    val soundId: Int, val duKienSec: Int, val thucTeSec: Double, val lyDo: String,
    val danhGia: Int, val khoaCung: Boolean
)

data class Favorite(val id: Int, val tanSo: Double, val doManh: Int, val soundId: Int, val ghiChu: String)

class Db(ctx: Context) : SQLiteOpenHelper(ctx, "ist.db", null, 1) {

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("""CREATE TABLE sounds(
            id INTEGER PRIMARY KEY AUTOINCREMENT, ten TEXT, uri TEXT, do_manh INTEGER,
            loai TEXT, thoi_diem INTEGER, co_loi INTEGER, loop_tot INTEGER,
            do_dai_sec REAL, ngay_them INTEGER)""")
        db.execSQL("""CREATE TABLE sessions(
            id INTEGER PRIMARY KEY AUTOINCREMENT, bat_dau INTEGER, tan_so REAL, band INTEGER,
            do_manh INTEGER, sound_id INTEGER, du_kien_sec INTEGER, thuc_te_sec REAL,
            ly_do TEXT, danh_gia INTEGER DEFAULT 99, khoa_cung INTEGER DEFAULT 0,
            dang_chay INTEGER DEFAULT 0)""")
        db.execSQL("""CREATE TABLE rejects(
            id INTEGER PRIMARY KEY AUTOINCREMENT, sound_id INTEGER, band INTEGER, ts INTEGER)""")
        db.execSQL("""CREATE TABLE favorites(
            id INTEGER PRIMARY KEY AUTOINCREMENT, tan_so REAL, do_manh INTEGER,
            sound_id INTEGER, ghi_chu TEXT)""")
        db.execSQL("CREATE INDEX idx_sess_time ON sessions(bat_dau)")
    }

    override fun onUpgrade(db: SQLiteDatabase, o: Int, n: Int) {}

    // ---------------- Kho ----------------
    fun addSound(s: Sound): Long = writableDatabase.insert("sounds", null, ContentValues().apply {
        put("ten", s.ten); put("uri", s.uri); put("do_manh", s.doManh); put("loai", s.loai)
        put("thoi_diem", s.thoiDiem); put("co_loi", if (s.coLoi) 1 else 0)
        put("loop_tot", if (s.loopTot) 1 else 0); put("do_dai_sec", s.doDaiSec)
        put("ngay_them", System.currentTimeMillis())
    })

    fun deleteSound(id: Int) { writableDatabase.delete("sounds", "id=?", arrayOf("$id")) }

    fun sounds(): List<Sound> {
        val out = ArrayList<Sound>()
        readableDatabase.rawQuery("SELECT id,ten,uri,do_manh,loai,thoi_diem,co_loi,loop_tot,do_dai_sec FROM sounds ORDER BY id", null).use { c ->
            while (c.moveToNext()) out.add(Sound(c.getInt(0), c.getString(1), c.getString(2), c.getInt(3),
                c.getString(4) ?: "", c.getInt(5), c.getInt(6) == 1, c.getInt(7) == 1, c.getDouble(8)))
        }
        return out
    }

    fun sound(id: Int): Sound? = sounds().firstOrNull { it.id == id }

    // ---------------- Phiên nghe ----------------
    fun startSession(tanSo: Double, band: Int, doManh: Int, soundId: Int, duKien: Int): Long =
        writableDatabase.insert("sessions", null, ContentValues().apply {
            put("bat_dau", System.currentTimeMillis()); put("tan_so", tanSo); put("band", band)
            put("do_manh", doManh); put("sound_id", soundId); put("du_kien_sec", duKien)
            put("thuc_te_sec", 0.0); put("ly_do", "dang_chay"); put("danh_gia", 99)
            put("dang_chay", 1)
        })

    /** Cập nhật định kỳ trong lúc phát => nếu OS kill tiến trình vẫn không mất bộ đếm an toàn. */
    fun updateProgress(id: Long, thucTe: Double) {
        writableDatabase.execSQL("UPDATE sessions SET thuc_te_sec=? WHERE id=?", arrayOf(thucTe, id))
    }

    fun finishSession(id: Long, thucTe: Double, lyDo: String, khoaCung: Boolean) {
        writableDatabase.execSQL(
            "UPDATE sessions SET thuc_te_sec=?, ly_do=?, khoa_cung=?, dang_chay=0 WHERE id=?",
            arrayOf(thucTe, lyDo, if (khoaCung) 1 else 0, id))
    }

    /** Phiên dở dang do bị kill: đánh dấu "Dừng sớm" khi mở lại app (mục 9.3). */
    fun recoverDangling() {
        writableDatabase.execSQL("UPDATE sessions SET ly_do='dung_som', dang_chay=0 WHERE dang_chay=1")
    }

    fun rate(id: Long, danhGia: Int) {
        writableDatabase.execSQL("UPDATE sessions SET danh_gia=? WHERE id=?", arrayOf(danhGia, id))
    }

    fun addReject(soundId: Int, band: Int) {
        writableDatabase.insert("rejects", null, ContentValues().apply {
            put("sound_id", soundId); put("band", band); put("ts", System.currentTimeMillis())
        })
    }

    fun sessions(limit: Int = 100): List<SessionRow> {
        val out = ArrayList<SessionRow>()
        readableDatabase.rawQuery(
            "SELECT id,bat_dau,tan_so,band,do_manh,sound_id,du_kien_sec,thuc_te_sec,ly_do,danh_gia,khoa_cung " +
            "FROM sessions ORDER BY bat_dau DESC LIMIT $limit", null).use { c ->
            while (c.moveToNext()) out.add(SessionRow(c.getLong(0), c.getLong(1), c.getDouble(2), c.getInt(3),
                c.getInt(4), c.getInt(5), c.getInt(6), c.getDouble(7), c.getString(8), c.getInt(9), c.getInt(10) == 1))
        }
        return out
    }

    // ---------------- Bộ đếm ngày / tuần (chương 8) ----------------
    companion object {
        fun startOfToday(): Long = Calendar.getInstance().apply {   // 00:00 GIỜ ĐỊA PHƯƠNG
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        fun startOfTomorrow(): Long = startOfToday() + 24L * 3600 * 1000
        /** Số ngày lịch tính từ hôm nay (0 = hôm nay, 1 = hôm qua...). */
        fun daysAgo(ts: Long): Int {
            val c = Calendar.getInstance().apply {
                timeInMillis = ts
                set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            }
            return ((startOfToday() - c.timeInMillis) / (24L * 3600 * 1000)).toInt().coerceAtLeast(0)
        }
    }

    /** Tổng giây CÓ PULSE theo từng band, tính từ 00:00 hôm nay. */
    fun dailyUsage(): DoubleArray {
        val out = DoubleArray(5)
        readableDatabase.rawQuery(
            "SELECT band, SUM(thuc_te_sec) FROM sessions WHERE bat_dau>=? GROUP BY band",
            arrayOf(startOfToday().toString())).use { c ->
            while (c.moveToNext()) { val b = c.getInt(0); if (b in 0..4) out[b] = c.getDouble(1) }
        }
        return out
    }

    fun weeklyUsage(): DoubleArray {
        val out = DoubleArray(5)
        val from = startOfToday() - 6L * 24 * 3600 * 1000
        readableDatabase.rawQuery(
            "SELECT band, SUM(thuc_te_sec) FROM sessions WHERE bat_dau>=? GROUP BY band",
            arrayOf(from.toString())).use { c ->
            while (c.moveToNext()) { val b = c.getInt(0); if (b in 0..4) out[b] = c.getDouble(1) }
        }
        return out
    }

    /** true nếu BẤT KỲ band nào đã chạm 35 phút hôm nay => khoá toàn bộ chức năng nghe. */
    fun lockedBand(): Int? {
        val u = dailyUsage()
        for (i in 0..4) if (u[i] >= Const.DAILY_BAND_LIMIT_SEC) return i
        return null
    }

    // ---------------- Dữ liệu cho engine random (chương 6) ----------------
    class Stats(
        val ids: IntArray, val strengths: IntArray, val slots: IntArray, val lastPlayed: IntArray,
        val plays7: IntArray, val hop: IntArray, val binhThuong: IntArray, val khongHop: IntArray,
        val rejected: IntArray
    )

    fun statsForBand(band: Int): Stats {
        val list = sounds()
        val n = list.size
        val ids = IntArray(n); val st = IntArray(n); val sl = IntArray(n)
        val lp = IntArray(n) { -1 }; val p7 = IntArray(n); val hop = IntArray(n)
        val bt = IntArray(n); val kh = IntArray(n); val rj = IntArray(n) { -1 }
        val weekAgo = startOfToday() - 6L * 24 * 3600 * 1000
        list.forEachIndexed { i, s ->
            ids[i] = s.id; st[i] = s.doManh; sl[i] = s.thoiDiem
            readableDatabase.rawQuery("SELECT MAX(bat_dau) FROM sessions WHERE sound_id=?", arrayOf("${s.id}")).use { c ->
                if (c.moveToFirst() && !c.isNull(0)) lp[i] = daysAgo(c.getLong(0))
            }
            readableDatabase.rawQuery("SELECT COUNT(*) FROM sessions WHERE sound_id=? AND bat_dau>=?",
                arrayOf("${s.id}", "$weekAgo")).use { c -> if (c.moveToFirst()) p7[i] = c.getInt(0) }
            readableDatabase.rawQuery(
                "SELECT danh_gia, COUNT(*) FROM sessions WHERE sound_id=? AND band=? GROUP BY danh_gia",
                arrayOf("${s.id}", "$band")).use { c ->
                while (c.moveToNext()) {
                    when (c.getInt(0)) {
                        1 -> hop[i] = c.getInt(1)
                        0 -> bt[i] = c.getInt(1)
                        -1 -> kh[i] = c.getInt(1)
                    }
                }
            }
            readableDatabase.rawQuery("SELECT MAX(ts) FROM rejects WHERE sound_id=?", arrayOf("${s.id}")).use { c ->
                if (c.moveToFirst() && !c.isNull(0)) rj[i] = daysAgo(c.getLong(0))
            }
        }
        return Stats(ids, st, sl, lp, p7, hop, bt, kh, rj)
    }

    // ---------------- Tổ hợp yêu thích ----------------
    fun addFavorite(f: Favorite) = writableDatabase.insert("favorites", null, ContentValues().apply {
        put("tan_so", f.tanSo); put("do_manh", f.doManh); put("sound_id", f.soundId); put("ghi_chu", f.ghiChu)
    })

    fun favorites(): List<Favorite> {
        val out = ArrayList<Favorite>()
        readableDatabase.rawQuery("SELECT id,tan_so,do_manh,sound_id,ghi_chu FROM favorites", null).use { c ->
            while (c.moveToNext()) out.add(Favorite(c.getInt(0), c.getDouble(1), c.getInt(2), c.getInt(3), c.getString(4) ?: ""))
        }
        return out
    }

    fun deleteFavorite(id: Int) { writableDatabase.delete("favorites", "id=?", arrayOf("$id")) }
}
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: app/src/main/java/com/personal/ist/AudioDecoder.kt
# ----------------------------------------------------------------------------
mkdir -p "app/src/main/java/com/personal/ist"
cat > 'app/src/main/java/com/personal/ist/AudioDecoder.kt' <<'IST__EOF__b7f3'
package com.personal.ist

import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Decode file âm nền -> PCM mono float, resample tuyến tính về sampleRate của engine.
 * Chạy ở thread nền (KHÔNG bao giờ gọi từ audio callback).
 */
object AudioDecoder {

    const val MAX_SECONDS = 300      // trần 5 phút cho 1 file nền (giới hạn RAM)

    fun decode(ctx: Context, uri: Uri, targetSr: Int): FloatArray {
        val ex = MediaExtractor()
        ctx.contentResolver.openFileDescriptor(uri, "r").use { pfd ->
            requireNotNull(pfd) { "Không mở được file" }
            ex.setDataSource(pfd.fileDescriptor)
        }
        var track = -1
        var fmt: MediaFormat? = null
        for (i in 0 until ex.trackCount) {
            val f = ex.getTrackFormat(i)
            if (f.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) { track = i; fmt = f; break }
        }
        require(track >= 0 && fmt != null) { "File không có track âm thanh" }
        ex.selectTrack(track)

        val srcSr = fmt.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        val ch = fmt.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        val codec = MediaCodec.createDecoderByType(fmt.getString(MediaFormat.KEY_MIME)!!)
        codec.configure(fmt, null, null, 0)
        codec.start()

        val pcm = ArrayList<Float>(srcSr * 30)
        val info = MediaCodec.BufferInfo()
        var inputDone = false
        var outputDone = false
        val maxSrcFrames = srcSr.toLong() * MAX_SECONDS

        while (!outputDone) {
            if (!inputDone) {
                val ib = codec.dequeueInputBuffer(10_000)
                if (ib >= 0) {
                    val buf = codec.getInputBuffer(ib)!!
                    val size = ex.readSampleData(buf, 0)
                    if (size < 0) {
                        codec.queueInputBuffer(ib, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        inputDone = true
                    } else {
                        codec.queueInputBuffer(ib, 0, size, ex.sampleTime, 0)
                        ex.advance()
                    }
                }
            }
            val ob = codec.dequeueOutputBuffer(info, 10_000)
            if (ob >= 0) {
                val out = codec.getOutputBuffer(ob)!!
                out.position(info.offset).limit(info.offset + info.size)
                val sb = out.order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
                val frames = sb.remaining() / ch
                for (i in 0 until frames) {
                    var acc = 0f
                    for (c in 0 until ch) acc += sb.get() / 32768f
                    pcm.add(acc / ch)                       // downmix mono
                }
                codec.releaseOutputBuffer(ob, false)
                if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
                if (pcm.size >= maxSrcFrames) outputDone = true
            } else if (ob == MediaCodec.INFO_TRY_AGAIN_LATER && inputDone && info.size == 0) {
                if (pcm.isNotEmpty()) outputDone = true
            }
        }
        codec.stop(); codec.release(); ex.release()

        val src = FloatArray(pcm.size) { pcm[it] }
        return if (srcSr == targetSr) src else resample(src, srcSr, targetSr)
    }

    private fun resample(src: FloatArray, from: Int, to: Int): FloatArray {
        if (src.isEmpty()) return src
        val ratio = to.toDouble() / from
        val n = (src.size * ratio).toInt()
        val out = FloatArray(n)
        for (i in 0 until n) {
            val x = i / ratio
            val i0 = x.toInt().coerceAtMost(src.size - 1)
            val i1 = (i0 + 1).coerceAtMost(src.size - 1)
            val f = (x - i0).toFloat()
            out[i] = src[i0] * (1 - f) + src[i1] * f
        }
        return out
    }

    /** Kiểm tra nhanh file (mục 4.4): trả về cảnh báo, người dùng quyết định cuối. */
    fun inspect(pcm: FloatArray, sr: Int): List<String> {
        val w = ArrayList<String>()
        val sec = pcm.size.toDouble() / sr
        if (sec < 20) w.add("File chỉ dài ${"%.1f".format(sec)}s — hơi ngắn, loop sẽ lặp dày")
        if (sec >= MAX_SECONDS - 1) w.add("File bị cắt ở $MAX_SECONDS s (giới hạn bộ nhớ)")
        var peak = 0f; var sum = 0.0
        for (s in pcm) { val a = kotlin.math.abs(s); if (a > peak) peak = a; sum += s.toDouble() * s }
        val rms = kotlin.math.sqrt(sum / pcm.size.coerceAtLeast(1))
        if (peak > 0.99f) w.add("Âm lượng đỉnh sát 0 dBFS — có thể đã bị clip sẵn")
        if (rms < 0.01) w.add("Âm lượng rất nhỏ (RMS ${"%.4f".format(rms)})")
        // khoảng lặng dài
        var run = 0; var maxRun = 0
        for (s in pcm) { if (kotlin.math.abs(s) < 0.002f) { run++; if (run > maxRun) maxRun = run } else run = 0 }
        if (maxRun > sr * 3) w.add("Có khoảng lặng dài ${maxRun / sr}s")
        return w
    }
}
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: app/src/main/java/com/personal/ist/PlaybackService.kt
# ----------------------------------------------------------------------------
mkdir -p "app/src/main/java/com/personal/ist"
cat > 'app/src/main/java/com/personal/ist/PlaybackService.kt' <<'IST__EOF__b7f3'
package com.personal.ist

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.net.Uri
import android.os.Build
import android.os.IBinder
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/** Trạng thái phát dùng chung cho UI (Compose quan sát qua StateFlow). */
data class PlaybackUi(
    val state: Int = NativeEngine.IDLE,
    val freqHz: Double = 10.0,
    val band: Int = 2,
    val strength: Int = 1,
    val soundName: String = "",
    val soundId: Int = -1,
    val plannedSec: Int = 0,
    val pulseSec: Double = 0.0,
    val dailySec: Double = 0.0,
    val sessionId: Long = -1,
    val endReason: Int = NativeEngine.R_NONE,
    val message: String = "",
    val pendingRatingSessionId: Long = -1
)

object Playback {
    private val _ui = MutableStateFlow(PlaybackUi())
    val ui: StateFlow<PlaybackUi> = _ui
    internal fun update(f: (PlaybackUi) -> PlaybackUi) { _ui.value = f(_ui.value) }

    fun start(ctx: Context, freqHz: Double, strength: Int, plannedMin: Int, ambientMin: Int, forcedSoundId: Int = -1) {
        val i = Intent(ctx, PlaybackService::class.java).apply {
            action = PlaybackService.ACT_START
            putExtra("freq", freqHz); putExtra("strength", strength)
            putExtra("planned", plannedMin); putExtra("ambient", ambientMin)
            putExtra("soundId", forcedSoundId)
        }
        if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
    }
    fun send(ctx: Context, action: String) {
        ctx.startService(Intent(ctx, PlaybackService::class.java).apply { this.action = action })
    }
}

class PlaybackService : Service() {

    companion object {
        const val ACT_START = "ist.start"
        const val ACT_PAUSE = "ist.pause"
        const val ACT_RESUME = "ist.resume"
        const val ACT_STOP = "ist.stop"
        const val ACT_SWAP = "ist.swap"          // nút "Không hợp"
        const val CHANNEL = "ist_playback"
        const val NOTIF_ID = 1001
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private lateinit var db: Db
    private var session: MediaSession? = null
    private var poller: Job? = null
    private var sessionId: Long = -1
    private var currentSoundId: Int = -1
    private var currentStrength: Int = 1
    private var currentBand: Int = 2
    private var dailyBeforeSec: Int = 0
    /** Mốc pulse-time khi hàng ghi hiện tại bắt đầu (đổi khi bấm "Không hợp"). */
    private var rowPulseOffset: Double = 0.0

    override fun onCreate() {
        super.onCreate()
        db = Db(this)
        createChannel()
        NativeEngine.nativeInit()
        session = MediaSession(this, "IsT").apply {
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() { NativeEngine.nativeResume() }
                override fun onPause() { NativeEngine.nativePause() }
                override fun onStop() { NativeEngine.nativeStop() }
            })
            isActive = true
        }
    }

    override fun onBind(i: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACT_START -> {
                val freq = intent.getDoubleExtra("freq", 10.0)
                val strength = intent.getIntExtra("strength", 1)
                val planned = intent.getIntExtra("planned", 20)
                val ambient = intent.getIntExtra("ambient", 0)
                val forced = intent.getIntExtra("soundId", -1)
                // Phải vào foreground ngay để không bị ANR (startForegroundService -> 5s)
                startForeground(NOTIF_ID, buildNotif())
                scope.launch { beginSession(freq, strength, planned, ambient, forced) }
            }
            ACT_PAUSE -> { NativeEngine.nativePause(); updateNotif() }
            ACT_RESUME -> { NativeEngine.nativeResume(); updateNotif() }
            ACT_STOP -> NativeEngine.nativeStop()
            ACT_SWAP -> scope.launch { swapBackground() }
        }
        return START_NOT_STICKY
    }

    // -------------------------------------------------------------------
    private suspend fun beginSession(freq: Double, strength: Int, plannedMin: Int, ambientMin: Int, forcedSoundId: Int) {
        // (1) KHOÁ CỨNG NGÀY - chặn trước khi phát, không có ngoại lệ (kể cả tổ hợp yêu thích)
        db.lockedBand()?.let { b ->
            Playback.update { it.copy(message = "🔒 Đã đạt giới hạn nghe an toàn hôm nay (${Const.BAND_NAMES[b]})") }
            stopForeground(true); stopSelf(); return
        }
        val band = Const.bandOf(freq)
        currentBand = band
        currentStrength = strength
        dailyBeforeSec = db.dailyUsage()[band].toInt()

        // (2) chọn âm nền: engine random C++ (hoặc tổ hợp yêu thích chỉ định sẵn)
        val sound = if (forcedSoundId > 0) db.sound(forcedSoundId) else pickSound(band, strength, -1)
        if (sound == null) {
            Playback.update { it.copy(message = "Kho chưa có âm nền ở mức \"${Const.STRENGTH_NAMES[strength]}\"") }
            stopForeground(true); stopSelf(); return
        }
        currentSoundId = sound.id

        // (3) decode file nền (thread nền)
        val sr = NativeEngine.nativeSampleRate().let { if (it > 0) it else 48000 }
        val pcm = try { AudioDecoder.decode(this, Uri.parse(sound.uri), sr) }
        catch (e: Exception) {
            Playback.update { it.copy(message = "Không đọc được file: ${sound.ten}") }
            stopForeground(true); stopSelf(); return
        }
        NativeEngine.nativeSetBackground(pcm)

        val plannedSec = (plannedMin * 60).coerceAtMost(Const.SESSION_HARD_LIMIT_MIN * 60)
        val ok = NativeEngine.nativeStart(
            freq, Const.bgGain(strength), plannedSec, ambientMin * 60, sound.loopTot, dailyBeforeSec)
        if (!ok) {
            Playback.update { it.copy(message = "🔒 Chức năng Nghe nhạc đang bị khoá đến 00:00") }
            stopForeground(true); stopSelf(); return
        }
        sessionId = db.startSession(freq, band, strength, sound.id, plannedSec)
        rowPulseOffset = 0.0
        Playback.update {
            PlaybackUi(state = NativeEngine.FADE_IN, freqHz = freq, band = band, strength = strength,
                soundName = sound.ten,
                soundId = sound.id, plannedSec = plannedSec, sessionId = sessionId,
                dailySec = dailyBeforeSec.toDouble())
        }
        updateNotif()
        startPoller()
    }

    private fun pickSound(band: Int, strength: Int, excludeId: Int): Sound? {
        val s = db.statsForBand(band)
        if (s.ids.isEmpty()) return null
        val hour = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)
        val slot = when (hour) { in 5..11 -> 0; in 12..17 -> 1; else -> 2 }
        val r = NativeEngine.nativePick(s.ids, s.strengths, s.slots, s.lastPlayed, s.plays7,
            s.hop, s.binhThuong, s.khongHop, s.rejected, strength, slot, System.nanoTime(), excludeId)
        if (r[3] == 1 || r[0] < 0) return null
        if (r[2] == 1) Playback.update { it.copy(message = "Đã nghe hết các lựa chọn phù hợp gần đây") }
        return db.sound(r[0])
    }

    /** "Không hợp": đổi nền cùng mức độ mạnh, fade mượt, state chính không đổi. */
    private suspend fun swapBackground() {
        val old = currentSoundId
        val next = pickSound(currentBand, currentStrength, old) ?: run {
            Playback.update { it.copy(message = "Không còn âm nền khác ở mức này") }; return
        }
        db.addReject(old, currentBand)
        val sr = NativeEngine.nativeSampleRate().let { if (it > 0) it else 48000 }
        val pcm = try { AudioDecoder.decode(this, Uri.parse(next.uri), sr) } catch (e: Exception) { return }
        NativeEngine.nativeSetBackground(pcm)
        currentSoundId = next.id
        // Ghi nhận phiên đổi nền: phần đã nghe VẪN cộng vào bộ đếm ngày (chương 8.3)
        val pulseNow = NativeEngine.nativePulseSeconds()
        db.finishSession(sessionId, pulseNow - rowPulseOffset, "khong_hop_doi_nen", false)
        rowPulseOffset = pulseNow          // hàng mới đếm tiếp từ đây (không cộng trùng)
        sessionId = db.startSession(Playback.ui.value.freqHz, currentBand, currentStrength, next.id,
            Playback.ui.value.plannedSec)
        Playback.update { it.copy(soundName = next.ten, soundId = next.id, sessionId = sessionId) }
    }

    private fun startPoller() {
        poller?.cancel()
        poller = scope.launch {
            var lastPersist = 0.0
            while (isActive) {
                val st = NativeEngine.nativeState()
                val pulse = NativeEngine.nativePulseSeconds()
                val daily = NativeEngine.nativeDailySeconds()
                Playback.update { it.copy(state = st, pulseSec = pulse, dailySec = daily) }
                if (pulse - lastPersist > 5.0) {     // chống mất dữ liệu nếu OS kill tiến trình
                    db.updateProgress(sessionId, pulse - rowPulseOffset)
                    lastPersist = pulse
                }
                updateNotif()
                if (st == NativeEngine.ENDED) { finalizeSession(pulse - rowPulseOffset); break }
                delay(400)
            }
        }
    }

    private fun finalizeSession(pulseSec: Double) {
        val reason = NativeEngine.nativeEndReason()
        val key = when (reason) {
            NativeEngine.R_KHOA_CUNG_NGAY -> "khoa_cung_ngay"
            NativeEngine.R_NGUOI_DUNG_DUNG -> "nguoi_dung_dung"
            else -> "het_gio_phien"
        }
        db.finishSession(sessionId, pulseSec, key, reason == NativeEngine.R_KHOA_CUNG_NGAY)
        Playback.update {
            it.copy(state = NativeEngine.ENDED, endReason = reason, pendingRatingSessionId = sessionId,
                message = if (reason == NativeEngine.R_KHOA_CUNG_NGAY)
                    "🔒 Đã đạt giới hạn nghe an toàn hôm nay" else "")
        }
        stopForeground(true)
        stopSelf()
    }

    // -------------------------------------------------------------------
    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            val ch = NotificationChannel(CHANNEL, "IsT đang phát", NotificationManager.IMPORTANCE_LOW)
            ch.setShowBadge(false)
            getSystemService(NotificationManager::class.java).createNotificationChannel(ch)
        }
    }

    private fun pi(action: String): PendingIntent {
        val i = Intent(this, PlaybackService::class.java).apply { this.action = action }
        return PendingIntent.getService(this, action.hashCode(), i,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun buildNotif(): Notification {
        val u = Playback.ui.value
        val paused = u.state == NativeEngine.PAUSED
        val content = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val remain = (u.plannedSec - u.pulseSec).coerceAtLeast(0.0)
        session?.setPlaybackState(
            PlaybackState.Builder()
                .setActions(PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_STOP)
                .setState(if (paused) PlaybackState.STATE_PAUSED else PlaybackState.STATE_PLAYING,
                    (u.pulseSec * 1000).toLong(), 1f)
                .build())
        val icon = android.graphics.drawable.Icon.createWithResource(this, R.drawable.ic_stat_ist)
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL)
                else @Suppress("DEPRECATION") Notification.Builder(this)
        return b.setSmallIcon(R.drawable.ic_stat_ist)
            .setContentTitle("IsT — ${"%.1f".format(u.freqHz)} Hz ${Const.BAND_NAMES[u.band]}")
            .setContentText("${u.soundName} · còn ${Const.fmt(remain)} · hôm nay ${Const.fmt(u.dailySec)}/35:00")
            .setContentIntent(content)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .addAction(Notification.Action.Builder(icon,
                if (paused) "Tiếp tục" else "Tạm dừng", pi(if (paused) ACT_RESUME else ACT_PAUSE)).build())
            .addAction(Notification.Action.Builder(icon, "Dừng", pi(ACT_STOP)).build())
            .setStyle(Notification.MediaStyle()
                .setMediaSession(session!!.sessionToken)
                .setShowActionsInCompactView(0, 1))
            .build()
    }

    private fun updateNotif() {
        if (Playback.ui.value.state == NativeEngine.ENDED) return
        getSystemService(NotificationManager::class.java).notify(NOTIF_ID, buildNotif())
    }

    override fun onDestroy() {
        poller?.cancel(); scope.cancel()
        session?.isActive = false; session?.release()
        super.onDestroy()
    }
}
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: app/src/main/java/com/personal/ist/MainActivity.kt
# ----------------------------------------------------------------------------
mkdir -p "app/src/main/java/com/personal/ist"
cat > 'app/src/main/java/com/personal/ist/MainActivity.kt' <<'IST__EOF__b7f3'
package com.personal.ist

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import kotlinx.coroutines.delay

// ----- Thương hiệu: nền đen, chữ vàng (mục 2) -----
val Gold = Color(0xFFD4AF37)
val GoldBright = Color(0xFFF2C230)
val BgBlack = Color(0xFF000000)
val Surface1 = Color(0xFF0A0A0A)
val TextDim = Color(0xFFB0B0B0)

enum class Screen { Home, Play, Now, Kho, History, Intro }

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val db = Db(this)
        db.recoverDangling()          // phiên bị OS kill -> "Dừng sớm" (mục 9.3)
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        }
        setContent {
            MaterialTheme(
                colorScheme = darkColorScheme(
                    primary = Gold, onPrimary = BgBlack, background = BgBlack,
                    surface = Surface1, onSurface = Color.White, secondary = Gold
                )
            ) { IstApp(db) }
        }
    }
}

@Composable
fun IstApp(db: Db) {
    val ctx = LocalContextSafe()
    val prefs = remember { ctx.getSharedPreferences("ist", 0) }
    var screen by remember { mutableStateOf(if (prefs.getBoolean("intro_done", false)) Screen.Home else Screen.Intro) }
    val ui by Playback.ui.collectAsState()

    // Tự nhảy sang màn "Đang nghe" khi engine bắt đầu chạy
    LaunchedEffect(ui.state) {
        if (NativeEngine.isActive(ui.state) && ui.state != NativeEngine.ENDED) screen = Screen.Now
    }

    Box(Modifier.fillMaxSize().background(BgBlack)) {
        when (screen) {
            Screen.Intro -> IntroScreen { prefs.edit().putBoolean("intro_done", true).apply(); screen = Screen.Home }
            Screen.Home -> HomeScreen(db) { screen = it }
            Screen.Play -> PlayScreen(db, onBack = { screen = Screen.Home })
            Screen.Now -> NowPlayingScreen(db, onDone = { screen = Screen.Home })
            Screen.Kho -> KhoScreen(db) { screen = Screen.Home }
            Screen.History -> HistoryScreen(db) { screen = Screen.Home }
        }
    }
}

@Composable fun LocalContextSafe() = androidx.compose.ui.platform.LocalContext.current

@Composable
fun Title(text: String) = Text(text, color = Gold, fontSize = 26.sp, fontWeight = FontWeight.SemiBold)

@Composable
fun GoldButton(text: String, enabled: Boolean = true, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Button(onClick = onClick, enabled = enabled, modifier = modifier,
        colors = ButtonDefaults.buttonColors(containerColor = Gold, contentColor = BgBlack,
            disabledContainerColor = Color(0xFF2A2A2A), disabledContentColor = Color(0xFF777777))) {
        Text(text, fontWeight = FontWeight.SemiBold)
    }
}

// ---------------------------------------------------------------- TRANG CHỦ
@Composable
fun HomeScreen(db: Db, go: (Screen) -> Unit) {
    val locked = remember { mutableStateOf(db.lockedBand()) }
    Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally) {
        Text("IsT", color = Gold, fontSize = 64.sp, fontWeight = FontWeight.Bold)
        Text("Isochronic Tones", color = TextDim, fontSize = 13.sp)
        Spacer(Modifier.height(48.dp))
        GoldButton("Nghe nhạc", modifier = Modifier.fillMaxWidth().height(56.dp)) { go(Screen.Play) }
        locked.value?.let {
            Spacer(Modifier.height(6.dp))
            Text("🔒 ${Const.BAND_NAMES[it]} đã đạt 35/35 phút hôm nay — mở lại lúc 00:00",
                color = GoldBright, fontSize = 12.sp)
        }
        Spacer(Modifier.height(16.dp))
        OutlinedButton(onClick = { go(Screen.Kho) }, modifier = Modifier.fillMaxWidth().height(52.dp)) {
            Text("Kho", color = Gold)
        }
        Spacer(Modifier.height(16.dp))
        OutlinedButton(onClick = { go(Screen.History) }, modifier = Modifier.fillMaxWidth().height(52.dp)) {
            Text("Lịch sử", color = Gold)
        }
    }
}

// ------------------------------------------------------- THIẾT LẬP NGHE NHẠC
@Composable
fun PlayScreen(db: Db, onBack: () -> Unit) {
    val ctx = LocalContextSafe()
    var freq by remember { mutableStateOf(10.0) }
    var strength by remember { mutableStateOf(1) }
    var minutes by remember { mutableStateOf(20) }
    var ambient by remember { mutableStateOf(0) }
    val daily = remember { mutableStateOf(db.dailyUsage()) }
    val lockedBand = remember { mutableStateOf(db.lockedBand()) }
    val ui by Playback.ui.collectAsState()
    val band = Const.bandOf(freq)
    val locked = lockedBand.value != null

    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            TextButton(onClick = onBack) { Text("‹ Trang chủ", color = Gold) }
        }
        Title("Nghe nhạc")
        Spacer(Modifier.height(20.dp))

        Text("%.1f Hz".format(freq), color = Color.White, fontSize = 40.sp, fontWeight = FontWeight.Bold)
        Text(Const.BAND_NAMES[band], color = Gold, fontSize = 16.sp)
        Slider(value = freq.toFloat(), onValueChange = { freq = (Math.round(it * 2) / 2.0) },
            valueRange = 1f..40f, steps = 77,
            colors = SliderDefaults.colors(thumbColor = Gold, activeTrackColor = Gold))

        if (daily.value[band] >= Const.DAILY_BAND_LIMIT_SEC) {
            Text("🔒 ${Const.BAND_NAMES[band]} đã đạt 35/35 phút hôm nay — mở lại lúc 00:00",
                color = GoldBright, fontSize = 13.sp)
        }

        Spacer(Modifier.height(16.dp))
        Text("Độ mạnh nền", color = TextDim)
        Row {
            Const.STRENGTH_NAMES.forEachIndexed { i, n ->
                FilterChip(selected = strength == i, onClick = { strength = i }, label = { Text(n) },
                    modifier = Modifier.padding(end = 8.dp),
                    colors = FilterChipDefaults.filterChipColors(selectedContainerColor = Gold,
                        selectedLabelColor = BgBlack))
            }
        }

        Spacer(Modifier.height(16.dp))
        Text("Thời lượng: $minutes phút (tối đa ${Const.SESSION_HARD_LIMIT_MIN})", color = TextDim)
        Slider(value = minutes.toFloat(), onValueChange = { minutes = it.toInt() },
            valueRange = 5f..35f, steps = 29,
            colors = SliderDefaults.colors(thumbColor = Gold, activeTrackColor = Gold))

        Text("Chế độ ngủ (nền phát tiếp sau khi pulse tắt)", color = TextDim)
        Row {
            listOf(0, 15, 30).forEach { m ->
                FilterChip(selected = ambient == m, onClick = { ambient = m },
                    label = { Text(if (m == 0) "Tắt" else "$m phút") }, modifier = Modifier.padding(end = 8.dp),
                    colors = FilterChipDefaults.filterChipColors(selectedContainerColor = Gold,
                        selectedLabelColor = BgBlack))
            }
        }

        Spacer(Modifier.height(20.dp))
        Card(colors = CardDefaults.cardColors(containerColor = Surface1)) {
            Column(Modifier.padding(12.dp)) {
                Text("Hạn mức hôm nay", color = Gold, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(6.dp))
                (0..4).forEach { b ->
                    val used = daily.value[b]
                    val full = used >= Const.DAILY_BAND_LIMIT_SEC
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(Const.BAND_NAMES[b], color = if (full) GoldBright else TextDim,
                            fontSize = 13.sp, modifier = Modifier.width(60.dp))
                        LinearProgressIndicator(
                            progress = { (used / Const.DAILY_BAND_LIMIT_SEC).toFloat().coerceIn(0f, 1f) },
                            modifier = Modifier.weight(1f).height(6.dp), color = if (full) GoldBright else Gold)
                        Text("  ${(used / 60).toInt()}/35${if (full) " 🔒" else ""}",
                            color = if (full) GoldBright else TextDim, fontSize = 12.sp)
                    }
                }
            }
        }

        if (locked) {
            Spacer(Modifier.height(16.dp))
            LockCard(lockedBand.value!!)
        }
        if (ui.message.isNotEmpty()) {
            Spacer(Modifier.height(8.dp))
            Text(ui.message, color = GoldBright, fontSize = 13.sp)
        }

        Spacer(Modifier.height(20.dp))
        GoldButton("Nghe", enabled = !locked, modifier = Modifier.fillMaxWidth().height(56.dp)) {
            Playback.start(ctx, freq, strength, minutes, ambient)
        }

        // Tổ hợp yêu thích (6.6) - vẫn tính vào mọi bộ đếm an toàn
        val favs = remember { db.favorites() }
        if (favs.isNotEmpty()) {
            Spacer(Modifier.height(20.dp))
            Text("Tổ hợp yêu thích", color = Gold)
            favs.forEach { f ->
                val name = db.sound(f.soundId)?.ten ?: "(đã xoá)"
                Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text("%.1f Hz · %s · %s".format(f.tanSo, Const.STRENGTH_NAMES[f.doManh], name),
                        color = TextDim, fontSize = 13.sp, modifier = Modifier.weight(1f))
                    TextButton(enabled = !locked,
                        onClick = { Playback.start(ctx, f.tanSo, f.doManh, minutes, ambient, f.soundId) }) {
                        Text("Phát", color = if (locked) Color.Gray else Gold)
                    }
                }
            }
        }
        Spacer(Modifier.height(40.dp))
    }
}

@Composable
fun LockCard(band: Int) {
    var now by remember { mutableStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) { while (true) { delay(1000); now = System.currentTimeMillis() } }
    val remain = (Db.startOfTomorrow() - now) / 1000.0
    Card(colors = CardDefaults.cardColors(containerColor = Color(0xFF1A1400))) {
        Column(Modifier.padding(16.dp)) {
            Text("🔒 Đã đạt giới hạn nghe an toàn hôm nay", color = GoldBright, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(8.dp))
            Text("Bạn đã nghe đủ 35 phút cho dải tần ${Const.BAND_NAMES[band]} hôm nay.\n" +
                 "Để tránh quá tải, chức năng Nghe nhạc tạm khoá đến 00:00 (còn ${Const.fmtLong(remain)}).",
                color = Color.White, fontSize = 13.sp)
            Spacer(Modifier.height(8.dp))
            Text("Đây là giới hạn cố định vì lý do an toàn, không thể mở khoá sớm hơn.",
                color = TextDim, fontSize = 12.sp)
        }
    }
}

// ------------------------------------------------------------- ĐANG NGHE
@Composable
fun NowPlayingScreen(db: Db, onDone: () -> Unit) {
    val ctx = LocalContextSafe()
    val ui by Playback.ui.collectAsState()
    var rated by remember { mutableStateOf(false) }

    Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.Center) {
        Text("Tần số", color = TextDim, fontSize = 13.sp)
        Text("%.1f Hz — %s".format(ui.freqHz, Const.BAND_NAMES[ui.band]), color = Color.White, fontSize = 28.sp)
        Spacer(Modifier.height(16.dp))
        Text("Đang phát", color = TextDim, fontSize = 13.sp)
        Text("\"${ui.soundName}\"", color = Gold, fontSize = 18.sp)
        Spacer(Modifier.height(16.dp))
        Text("Đã nghe", color = TextDim, fontSize = 13.sp)
        Text("${Const.fmtLong(ui.pulseSec)} / ${Const.fmtLong(ui.plannedSec.toDouble())}",
            color = Color.White, fontSize = 20.sp)
        Spacer(Modifier.height(8.dp))
        Text("Hạn mức ngày: ${Const.BAND_NAMES[ui.band]} ${Const.fmt(ui.dailySec)}/35:00",
            color = if (ui.dailySec >= Const.DAILY_BAND_LIMIT_SEC * 0.9) GoldBright else TextDim, fontSize = 13.sp)
        LinearProgressIndicator(
            progress = { (ui.dailySec / Const.DAILY_BAND_LIMIT_SEC).toFloat().coerceIn(0f, 1f) },
            modifier = Modifier.fillMaxWidth().height(6.dp).padding(top = 6.dp), color = Gold)

        Spacer(Modifier.height(12.dp))
        Text("Trạng thái: " + when (ui.state) {
            NativeEngine.FADE_IN -> "Đang vào (fade-in)"
            NativeEngine.PLAYING -> "Đang phát"
            NativeEngine.PAUSED -> "Tạm dừng"
            NativeEngine.FADE_OUT_TONE_ONLY -> "Tắt dần tone (chế độ ngủ)"
            NativeEngine.AMBIENT_ONLY -> "Chỉ còn âm nền"
            NativeEngine.FADE_OUT -> "Đang kết thúc"
            else -> "Đã dừng"
        }, color = TextDim, fontSize = 13.sp)

        Spacer(Modifier.height(28.dp))
        if (ui.state != NativeEngine.ENDED) {
            Row {
                GoldButton(if (ui.state == NativeEngine.PAUSED) "Tiếp tục" else "Tạm dừng") {
                    Playback.send(ctx, if (ui.state == NativeEngine.PAUSED)
                        PlaybackService.ACT_RESUME else PlaybackService.ACT_PAUSE)
                }
                Spacer(Modifier.width(12.dp))
                OutlinedButton(onClick = { Playback.send(ctx, PlaybackService.ACT_STOP) }) {
                    Text("Dừng", color = Gold)
                }
                Spacer(Modifier.width(12.dp))
                OutlinedButton(onClick = { Playback.send(ctx, PlaybackService.ACT_SWAP) }) {
                    Text("Không hợp", color = Gold)
                }
            }
            Spacer(Modifier.height(12.dp))
            var saved by remember { mutableStateOf(false) }
            TextButton(enabled = !saved, onClick = {
                db.addFavorite(Favorite(0, ui.freqHz, ui.strength, ui.soundId, ui.soundName))
                saved = true
            }) { Text(if (saved) "★ Đã lưu tổ hợp" else "☆ Lưu tổ hợp yêu thích", color = Gold) }
        } else {
            if (ui.endReason == NativeEngine.R_KHOA_CUNG_NGAY) {
                LockCard(ui.band); Spacer(Modifier.height(16.dp))
            }
            if (!rated) {
                Text("Phiên vừa rồi thế nào?", color = Color.White)
                Spacer(Modifier.height(8.dp))
                Row {
                    listOf("Hợp" to 1, "Bình thường" to 0, "Không hợp" to -1).forEach { (label, v) ->
                        OutlinedButton(onClick = { db.rate(ui.pendingRatingSessionId, v); rated = true },
                            modifier = Modifier.padding(end = 8.dp)) { Text(label, color = Gold) }
                    }
                }
                Spacer(Modifier.height(16.dp))
            }
            GoldButton("Về trang chủ") { onDone() }
        }
        if (ui.message.isNotEmpty()) {
            Spacer(Modifier.height(16.dp))
            Text(ui.message, color = GoldBright, fontSize = 13.sp)
        }
    }
}

// ----------------------------------------------------------------- GIỚI THIỆU
@Composable
fun IntroScreen(onOk: () -> Unit) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp)) {
        Spacer(Modifier.height(24.dp))
        Text("IsT", color = Gold, fontSize = 48.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(16.dp))
        Text("Lưu ý an toàn", color = Gold, fontSize = 20.sp)
        Spacer(Modifier.height(12.dp))
        listOf(
            "Không sử dụng khi lái xe, vận hành máy móc hoặc khi cần phản ứng nhanh.",
            "Nên bắt đầu ở âm lượng thấp và thời lượng ngắn.",
            "Dừng ngay nếu cảm thấy đau đầu, chóng mặt, khó chịu hoặc căng thẳng.",
            "Người có tiền sử co giật, động kinh, hoặc nhạy cảm với kích thích nhịp nên tham khảo ý kiến chuyên gia y tế trước khi dùng.",
            "Đây là công cụ hỗ trợ thư giãn cá nhân, không phải công cụ điều trị y tế.",
            "IsT giới hạn tối đa 35 phút/ngày cho mỗi dải tần số, đây là giới hạn an toàn cố định, không thể tắt."
        ).forEach { Text("•  $it", color = Color.White, fontSize = 14.sp, modifier = Modifier.padding(bottom = 10.dp)) }
        Spacer(Modifier.height(16.dp))
        GoldButton("Tôi đã hiểu", modifier = Modifier.fillMaxWidth().height(52.dp)) { onOk() }
        Spacer(Modifier.height(24.dp))
    }
}
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: app/src/main/java/com/personal/ist/Screens2.kt
# ----------------------------------------------------------------------------
mkdir -p "app/src/main/java/com/personal/ist"
cat > 'app/src/main/java/com/personal/ist/Screens2.kt' <<'IST__EOF__b7f3'
package com.personal.ist

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.util.*

// ------------------------------------------------------------------- KHO
@Composable
fun KhoScreen(db: Db, onBack: () -> Unit) {
    val ctx = LocalContextSafe()
    var list by remember { mutableStateOf(db.sounds()) }
    var pending by remember { mutableStateOf<Uri?>(null) }
    var warnings by remember { mutableStateOf<List<String>>(emptyList()) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            try {
                ctx.contentResolver.takePersistableUriPermission(uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } catch (_: Exception) {}
            pending = uri
        }
    }

    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp)) {
        TextButton(onClick = onBack) { Text("‹ Trang chủ", color = Gold) }
        Title("Kho âm nền")
        Spacer(Modifier.height(12.dp))
        GoldButton("Lưu thêm âm nền") { picker.launch(arrayOf("audio/*")) }
        Spacer(Modifier.height(16.dp))
        if (list.isEmpty()) Text("Kho trống. Thêm file nhạc nền (wav/mp3/m4a/ogg).", color = TextDim)
        list.forEach { s ->
            Card(Modifier.fillMaxWidth().padding(vertical = 4.dp),
                colors = CardDefaults.cardColors(containerColor = Surface1)) {
                Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(s.ten, color = Color.White, fontWeight = FontWeight.SemiBold)
                        Text("${Const.STRENGTH_NAMES[s.doManh]} · ${s.loai.ifEmpty { "—" }} · " +
                             "${Const.SLOT_NAMES[s.thoiDiem]} · ${if (s.loopTot) "loop tốt" else "loop thường"}" +
                             (if (s.coLoi) " · có lời" else ""), color = TextDim, fontSize = 12.sp)
                    }
                    TextButton(onClick = { db.deleteSound(s.id); list = db.sounds() }) {
                        Text("Xoá", color = Color(0xFFAA6666))
                    }
                }
            }
        }
        Spacer(Modifier.height(40.dp))
    }

    if (pending != null) {
        AddSoundDialog(db, pending!!, onDismiss = { pending = null; warnings = emptyList() }) {
            list = db.sounds(); pending = null
        }
    }
}

@Composable
fun AddSoundDialog(db: Db, uri: Uri, onDismiss: () -> Unit, onSaved: () -> Unit) {
    val ctx = LocalContextSafe()
    var ten by remember { mutableStateOf("") }
    var doManh by remember { mutableStateOf(1) }
    var loai by remember { mutableStateOf("") }
    var slot by remember { mutableStateOf(3) }
    var coLoi by remember { mutableStateOf(false) }
    var loopTot by remember { mutableStateOf(true) }
    var warn by remember { mutableStateOf<List<String>>(emptyList()) }
    var doDai by remember { mutableStateOf(0.0) }
    var checking by remember { mutableStateOf(true) }

    LaunchedEffect(uri) {
        withContext(Dispatchers.IO) {
            try {
                val sr = NativeEngine.nativeSampleRate().let { if (it > 0) it else 48000 }
                val pcm = AudioDecoder.decode(ctx, uri, sr)
                doDai = pcm.size.toDouble() / sr
                warn = AudioDecoder.inspect(pcm, sr)
            } catch (e: Exception) { warn = listOf("Không phát được file: ${e.message}") }
            checking = false
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Surface1,
        title = { Text("Thêm âm nền", color = Gold) },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState())) {
                OutlinedTextField(ten, { ten = it }, label = { Text("Tên (bắt buộc)") })
                Spacer(Modifier.height(8.dp))
                Text("Độ mạnh (bắt buộc)", color = TextDim, fontSize = 12.sp)
                Row {
                    Const.STRENGTH_NAMES.forEachIndexed { i, n ->
                        FilterChip(doManh == i, { doManh = i }, { Text(n) }, Modifier.padding(end = 6.dp))
                    }
                }
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(loai, { loai = it }, label = { Text("Loại âm thanh (tuỳ chọn)") })
                Spacer(Modifier.height(8.dp))
                Text("Thời điểm phù hợp", color = TextDim, fontSize = 12.sp)
                Row {
                    Const.SLOT_NAMES.forEachIndexed { i, n ->
                        FilterChip(slot == i, { slot = i }, { Text(n) }, Modifier.padding(end = 6.dp))
                    }
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(coLoi, { coLoi = it }); Text("Có lời", color = Color.White)
                    Spacer(Modifier.width(12.dp))
                    Checkbox(loopTot, { loopTot = it }); Text("Loop tốt", color = Color.White)
                }
                if (checking) Text("Đang kiểm tra file…", color = TextDim, fontSize = 12.sp)
                else {
                    Text("Độ dài: ${"%.1f".format(doDai)} s", color = TextDim, fontSize = 12.sp)
                    warn.forEach { Text("⚠ $it", color = GoldBright, fontSize = 12.sp) }
                    if (warn.isEmpty()) Text("✓ File hợp lệ", color = Gold, fontSize = 12.sp)
                }
            }
        },
        confirmButton = {
            TextButton(enabled = ten.isNotBlank(), onClick = {
                db.addSound(Sound(0, ten.trim(), uri.toString(), doManh, loai, slot, coLoi, loopTot, doDai))
                onSaved()
            }) { Text("Lưu", color = Gold) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Huỷ", color = TextDim) } }
    )
}

// --------------------------------------------------------------- LỊCH SỬ
@Composable
fun HistoryScreen(db: Db, onBack: () -> Unit) {
    val daily = remember { db.dailyUsage() }
    val weekly = remember { db.weeklyUsage() }
    val sessions = remember { db.sessions(60) }
    val fmt = remember { SimpleDateFormat("dd/MM HH:mm", Locale.getDefault()) }

    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp)) {
        TextButton(onClick = onBack) { Text("‹ Trang chủ", color = Gold) }
        Title("Lịch sử")

        Spacer(Modifier.height(16.dp))
        Text("Hôm nay", color = Gold, fontWeight = FontWeight.SemiBold)
        (0..4).forEach { b ->
            val used = daily[b]
            val full = used >= Const.DAILY_BAND_LIMIT_SEC
            Row(Modifier.fillMaxWidth().padding(vertical = 2.dp)) {
                Text(Const.BAND_NAMES[b], color = TextDim, modifier = Modifier.width(70.dp), fontSize = 13.sp)
                Text(Const.fmt(used), color = Color.White, modifier = Modifier.width(70.dp), fontSize = 13.sp)
                Text("/ 35:00", color = TextDim, modifier = Modifier.width(70.dp), fontSize = 13.sp)
                Text(if (full) "🔒 Đã khoá" else "Bình thường",
                    color = if (full) GoldBright else TextDim, fontSize = 13.sp)
            }
        }

        Spacer(Modifier.height(16.dp))
        Text("Tuần này (7 ngày)", color = Gold, fontWeight = FontWeight.SemiBold)
        (0..4).forEach { b ->
            Row(Modifier.fillMaxWidth().padding(vertical = 2.dp)) {
                Text(Const.BAND_NAMES[b], color = TextDim, modifier = Modifier.width(70.dp), fontSize = 13.sp)
                Text(Const.fmtLong(weekly[b]), color = Color.White, fontSize = 13.sp)
            }
        }

        Spacer(Modifier.height(16.dp))
        Text("Chi tiết từng phiên", color = Gold, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.height(6.dp))
        sessions.forEach { s ->
            Card(Modifier.fillMaxWidth().padding(vertical = 3.dp),
                colors = CardDefaults.cardColors(containerColor = Surface1)) {
                Column(Modifier.padding(10.dp)) {
                    Text("${fmt.format(Date(s.batDau))} · %.1f Hz %s · %s".format(
                        s.tanSo, Const.BAND_NAMES[s.band], Const.STRENGTH_NAMES[s.doManh]),
                        color = Color.White, fontSize = 13.sp)
                    Text("Đã nghe ${Const.fmt(s.thucTeSec)} / dự kiến ${Const.fmt(s.duKienSec.toDouble())} · " +
                         "${db.sound(s.soundId)?.ten ?: "—"}", color = TextDim, fontSize = 12.sp)
                    Text("Lý do: ${s.lyDo} · Bị khoá cứng do vượt hạn mức ngày? " +
                         (if (s.khoaCung) "Có" else "Không") +
                         " · Đánh giá: " + when (s.danhGia) { 1 -> "Hợp"; 0 -> "Bình thường"; -1 -> "Không hợp"; else -> "—" },
                        color = TextDim, fontSize = 12.sp)
                }
            }
        }
        Spacer(Modifier.height(40.dp))
    }
}
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: app/src/main/res/values/colors.xml
# ----------------------------------------------------------------------------
mkdir -p "app/src/main/res/values"
cat > 'app/src/main/res/values/colors.xml' <<'IST__EOF__b7f3'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ist_black">#FF000000</color>
    <color name="ist_surface">#FF0A0A0A</color>
    <color name="ist_gold">#FFD4AF37</color>       <!-- vang anh kim, chot cho v1 -->
    <color name="ist_gold_bright">#FFF2C230</color><!-- du phong khi can tuong phan manh -->
</resources>
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: app/src/main/res/values/strings.xml
# ----------------------------------------------------------------------------
mkdir -p "app/src/main/res/values"
cat > 'app/src/main/res/values/strings.xml' <<'IST__EOF__b7f3'
<resources>
    <string name="app_name">IsT</string>
</resources>
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: app/src/main/res/values/themes.xml
# ----------------------------------------------------------------------------
mkdir -p "app/src/main/res/values"
cat > 'app/src/main/res/values/themes.xml' <<'IST__EOF__b7f3'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.IsT" parent="android:Theme.Material.NoActionBar">
        <item name="android:windowBackground">@color/ist_black</item>
        <item name="android:statusBarColor">@color/ist_black</item>
        <item name="android:navigationBarColor">@color/ist_black</item>
    </style>
    <!-- Splash: nen den, logo chu vang canh giua -->
    <style name="Theme.IsT.Splash" parent="Theme.IsT">
        <item name="android:windowBackground">@drawable/splash_background</item>
    </style>
</resources>
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: app/src/main/res/drawable/splash_background.xml
# ----------------------------------------------------------------------------
mkdir -p "app/src/main/res/drawable"
cat > 'app/src/main/res/drawable/splash_background.xml' <<'IST__EOF__b7f3'
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/ist_black" />
    <item android:gravity="center">
        <bitmap android:src="@mipmap/ic_launcher" android:gravity="center" />
    </item>
</layer-list>
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: app/src/main/res/drawable/ic_stat_ist.xml
# ----------------------------------------------------------------------------
mkdir -p "app/src/main/res/drawable"
cat > 'app/src/main/res/drawable/ic_stat_ist.xml' <<'IST__EOF__b7f3'
<!-- Bien the don sac cho thanh trang thai / notification: xung vuong isochronic -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp" android:height="24dp"
    android:viewportWidth="24" android:viewportHeight="24">
    <path android:fillColor="#FFFFFFFF"
        android:pathData="M1,14 h3 v-4 h4 v4 h3 v-4 h4 v4 h3 v-4 h4 v6 h-2 v-4 h-3 v4 h-4 v-4 h-3 v4 h-4 v-4 h-3 v4 h-2 z" />
</vector>
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
# ----------------------------------------------------------------------------
mkdir -p "app/src/main/res/mipmap-anydpi-v26"
cat > 'app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml' <<'IST__EOF__b7f3'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ist_black" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml
# ----------------------------------------------------------------------------
mkdir -p "app/src/main/res/mipmap-anydpi-v26"
cat > 'app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml' <<'IST__EOF__b7f3'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ist_black" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: tests/test_core.cpp
# ----------------------------------------------------------------------------
mkdir -p "tests"
cat > 'tests/test_core.cpp' <<'IST__EOF__b7f3'
// tests/test_core.cpp
// Bộ kiểm thử lõi audio IsT. Chạy trên máy host (không cần Android) để xác minh
// độ chính xác nhịp isochronic TRƯỚC khi ghép lên app.
#include "ist/dsp.h"
#include "ist/session.h"
#include "ist/scoring.h"
#include <cstdio>
#include <cmath>
#include <vector>
#include <string>
#include <map>
#include <chrono>

using namespace ist;

static int g_pass = 0, g_fail = 0;
static void check(bool ok, const std::string& name, const std::string& info = "") {
    if (ok) { ++g_pass; printf("  [PASS] %-58s %s\n", name.c_str(), info.c_str()); }
    else    { ++g_fail; printf("  [FAIL] %-58s %s\n", name.c_str(), info.c_str()); }
}
static std::string f2s(double v, int prec = 6) {
    char b[128]; snprintf(b, sizeof b, "%.*f", prec, v); return b;
}
static void section(const char* t) { printf("\n=== %s ===\n", t); }

// ---------------------------------------------------------------------------
// T1. Độ chính xác & trôi nhịp của PulseGate (phase accumulator sample-accurate)
// ---------------------------------------------------------------------------
struct DriftResult { double maxErrSamples; double lastErrSamples; long pulses; double measuredHz; };

static DriftResult driftTest(double sr, double freq, double minutes) {
    PulseGate g; g.prepare(sr, freq, 0.5, 5.0); g.reset();
    const int64_t total = int64_t(sr * 60.0 * minutes);
    bool prevOpen = false;
    long k = 0; double maxErr = 0, lastErr = 0;
    int64_t firstOnset = -1, lastOnset = 0;
    for (int64_t n = 0; n < total; ++n) {
        bool open = g.gateOpen();
        if (open && !prevOpen) {
            double ideal = double(k) * sr / freq;       // mốc lý thuyết (số mẫu)
            double err = std::fabs(double(n) - ideal);
            if (err > maxErr) maxErr = err;
            lastErr = double(n) - ideal;
            if (firstOnset < 0) firstOnset = n;
            lastOnset = n; ++k;
        }
        prevOpen = open;
        g.next();
    }
    double measured = (k > 1) ? (double(k - 1) * sr / double(lastOnset - firstOnset)) : 0.0;
    return {maxErr, lastErr, k, measured};
}

static void testPulseTiming() {
    section("T1. Nhip isochronic: do chinh xac & troi nhip dai han");
    struct Case { double sr, hz, minutes; };
    std::vector<Case> cases = {
        {48000, 10.0, 60}, {48000, 7.5, 60},      // chạy dài 60 phút
        {48000, 1.0, 10},  {48000, 8.0, 10}, {48000, 12.5, 10}, {48000, 40.0, 10},
        {44100, 10.0, 10}, {44100, 7.5, 10},  {44100, 40.0, 10}, {44100, 0.5 + 8.0, 10}
    };
    for (auto& c : cases) {
        DriftResult r = driftTest(c.sr, c.hz, c.minutes);
        long expected = long(std::floor(c.hz * 60.0 * c.minutes)) ;
        char info[256];
        snprintf(info, sizeof info,
                 "sr=%.0f f=%.1fHz %.0fph: pulses=%ld (ky vong ~%ld) maxErr=%.3f mau (%.4f ms) do duoc=%.6f Hz",
                 c.sr, c.hz, c.minutes, r.pulses, expected, r.maxErrSamples,
                 r.maxErrSamples * 1000.0 / c.sr, r.measuredHz);
        // Sai số onset phải < 1 mẫu (chỉ do lượng tử hoá mẫu), KHÔNG được tăng theo thời gian.
        bool ok = r.maxErrSamples <= 1.0
                  && std::llabs((long long)r.pulses - (long long)expected) <= 1
                  && std::fabs(r.measuredHz - c.hz) < 1e-6;
        check(ok, "Timing/drift", info);
    }
}

// ---------------------------------------------------------------------------
// T2. Duty cycle
// ---------------------------------------------------------------------------
static void testDutyCycle() {
    section("T2. Duty cycle 50%");
    for (double hz : {1.0, 8.0, 10.0, 25.0, 40.0}) {
        PulseGate g; g.prepare(48000, hz, 0.5, 5.0);
        int64_t total = 48000 * 60, on = 0;
        for (int64_t n = 0; n < total; ++n) { if (g.gateOpen()) ++on; g.next(); }
        double duty = double(on) / double(total);
        check(std::fabs(duty - 0.5) < 1e-4, "Duty = 0.5 tai " + f2s(hz, 1) + " Hz",
              "do duoc=" + f2s(duty, 6));
    }
}

// ---------------------------------------------------------------------------
// T3. Envelope raised-cosine 5ms hai canh
// ---------------------------------------------------------------------------
static void testEnvelope() {
    section("T3. Envelope raised-cosine (Hann half-window) 5ms");
    const double sr = 48000, hz = 10.0, edgeMs = 5.0;
    PulseGate g; g.prepare(sr, hz, 0.5, edgeMs);
    std::vector<float> env;
    for (int n = 0; n < int(sr / hz); ++n) env.push_back(g.next());
    const int edge = int(edgeMs * 0.001 * sr);           // 240 mẫu
    double maxDev = 0;
    for (int n = 0; n < edge; ++n) {
        double ideal = 0.5 - 0.5 * std::cos(kPi * double(n) / double(edge));
        maxDev = std::max(maxDev, std::fabs(double(env[n]) - ideal));
    }
    check(maxDev < 1e-6, "Canh len khop raised-cosine", "maxDev=" + f2s(maxDev, 9));

    bool mono = true;
    for (int n = 1; n < edge; ++n) if (env[n] < env[n - 1]) mono = false;
    check(mono, "Canh len don dieu tang", "");
    check(env[0] < 1e-6, "Bat dau tu 0 (khong click)", "env[0]=" + f2s(env[0], 8));

    int onEnd = int(sr / hz * 0.5);
    check(env[onEnd - 1] < 0.02 && env[onEnd] == 0.0f, "Canh xuong ve 0 truoc khi tat",
          "env[on-1]=" + f2s(env[onEnd - 1], 6));
    // plateau giữa pulse = 1.0
    check(std::fabs(env[onEnd / 2] - 1.0f) < 1e-6, "Dinh pulse = 1.0", "");

    // độ dốc lớn nhất (proxy cho 'click'): phải nhỏ hơn nhiều so với gate vuông
    double maxStep = 0;
    for (size_t n = 1; n < env.size(); ++n) maxStep = std::max(maxStep, (double)std::fabs(env[n] - env[n - 1]));
    check(maxStep < 0.01, "Khong co buoc nhay (chong click)", "maxStep=" + f2s(maxStep, 6));

    // tần số cao: cạnh tự co lại, vẫn không click
    PulseGate g40; g40.prepare(sr, 40.0, 0.5, 5.0);
    double onS = g40.onSamples(), edgeS = g40.edgeSamples();
    check(edgeS <= onS * 0.5 + 1e-9, "40Hz: canh tu co lai vua pha bat",
          "on=" + f2s(onS, 1) + " mau, edge=" + f2s(edgeS, 1) + " mau");
}

// ---------------------------------------------------------------------------
// T4. Carrier 200 Hz sine
// ---------------------------------------------------------------------------
static void testCarrier() {
    section("T4. Carrier 200 Hz sine");
    const double sr = 48000;
    SineOsc o; o.prepare(sr, 200.0);
    int64_t N = int64_t(sr * 30);
    long zc = 0; float prev = 0; double maxAbs = 0, sumSq = 0; int64_t firstZc = -1, lastZc = 0;
    std::vector<float> buf; buf.reserve(N);
    for (int64_t n = 0; n < N; ++n) {
        float s = o.next(); buf.push_back(s);
        if (n > 0 && prev < 0 && s >= 0) { ++zc; if (firstZc < 0) firstZc = n; lastZc = n; }
        prev = s; maxAbs = std::max(maxAbs, std::fabs((double)s)); sumSq += double(s) * s;
    }
    double measured = double(zc - 1) * sr / double(lastZc - firstZc);
    check(std::fabs(measured - 200.0) < 0.02, "Tan so carrier", "do duoc=" + f2s(measured, 4) + " Hz");
    check(std::fabs(maxAbs - 1.0) < 1e-3, "Bien do dinh ~1.0", "peak=" + f2s(maxAbs, 6));
    double rms = std::sqrt(sumSq / double(N));
    check(std::fabs(rms - 0.70710678) < 1e-3, "RMS = 0.7071 (sine thuan)", "rms=" + f2s(rms, 6));
    // THD thô: so với sine lý tưởng
    double err = 0;
    for (int64_t n = 0; n < 48000; ++n) {
        double ideal = std::sin(2.0 * kPi * 200.0 * double(n) / sr);
        err = std::max(err, std::fabs(ideal - buf[n]));
    }
    check(err < 1e-4, "Sai lech so voi sine ly tuong", "maxErr=" + f2s(err, 8));
}

// ---------------------------------------------------------------------------
// T5. Ducking feed-forward
// ---------------------------------------------------------------------------
static void testDucking() {
    section("T5. Ducking feed-forward (-4 dB, 15/60 ms)");
    const double sr = 48000;
    AppConfig cfg;
    PulseGate g; g.prepare(sr, 5.0, 0.5, 5.0);
    Ducker d; d.prepare(sr, cfg.duckAmountDb, cfg.duckAttackMs, cfg.duckReleaseMs);
    double minG = 1, maxG = 0; int64_t minIdx = 0;
    std::vector<double> gains; std::vector<char> open;
    for (int64_t n = 0; n < int64_t(sr); ++n) {
        bool o = g.gateOpen(); float e = g.next();
        double gg = d.next(e);
        gains.push_back(gg); open.push_back(o);
        if (n > int64_t(sr * 0.4)) { if (gg < minG) { minG = gg; minIdx = n; } maxG = std::max(maxG, gg); }
    }
    double target = std::pow(10.0, cfg.duckAmountDb / 20.0);
    check(std::fabs(minG - target) < 0.01, "Muc duck day dat -4 dB",
          "min=" + f2s(minG, 5) + " (target " + f2s(target, 5) + ")");
    check(maxG > 0.92, "Phuc hoi gan het ve 0 dB giua cac nhip (release 60ms)", "max=" + f2s(maxG, 5));
    check(open[minIdx] == 1, "Diem duck sau nhat nam TRONG pha pulse bat (dong bo)", "");
    // attack: thời gian từ khi pulse mở tới khi đạt 63% mức giảm
    int64_t start = -1; for (size_t n = 1; n < open.size(); ++n) if (open[n] && !open[n-1] && n > sr*0.4) { start = n; break; }
    double thr63 = 1.0 - 0.63 * (1.0 - target);
    int64_t hit = start; while (hit < (int64_t)gains.size() && gains[hit] > thr63) ++hit;
    double atkMs = double(hit - start) * 1000.0 / sr;
    check(std::fabs(atkMs - cfg.duckAttackMs) < 4.0, "Attack ~15 ms", "do duoc=" + f2s(atkMs, 2) + " ms");
}

// ---------------------------------------------------------------------------
// T6. Limiter
// ---------------------------------------------------------------------------
static void testLimiter() {
    section("T6. Limiter -1 dBFS, lookahead 5 ms");
    const double sr = 48000; AppConfig cfg;
    Limiter L; L.prepare(sr, cfg.limiterThresholdDb, cfg.limiterLookaheadMs, cfg.limiterReleaseMs);
    double thr = std::pow(10.0, cfg.limiterThresholdDb / 20.0);
    double maxOut = 0;
    for (int64_t n = 0; n < int64_t(sr * 10); ++n) {
        double t = double(n) / sr;
        float x = float(1.8 * std::sin(2 * kPi * 200 * t) * (t > 2 && t < 6 ? 1.0 : 0.25));
        float y = L.next(x);
        maxOut = std::max(maxOut, std::fabs((double)y));
    }
    check(maxOut <= thr + 1e-6, "Khong bao gio vuot -1 dBFS",
          "peak=" + f2s(maxOut, 6) + " (thr " + f2s(thr, 6) + ")");
    check(L.hardClipCount() < sr * 0.01, "Hard-clamp an toan hiem khi phai can thiep",
          "so mau bi clamp=" + std::to_string(L.hardClipCount()));

    // Tín hiệu dưới ngưỡng phải đi qua nguyên vẹn (chỉ trễ lookahead)
    Limiter L2; L2.prepare(sr, cfg.limiterThresholdDb, cfg.limiterLookaheadMs, cfg.limiterReleaseMs);
    int lookSamples = int(cfg.limiterLookaheadMs * 0.001 * sr);
    std::vector<float> in, out;
    for (int n = 0; n < 4800; ++n) { float x = float(0.5 * std::sin(2 * kPi * 200 * n / sr)); in.push_back(x); out.push_back(L2.next(x)); }
    double dev = 0;
    for (int n = lookSamples + 10; n < 4800; ++n) dev = std::max(dev, (double)std::fabs(out[n] - in[n - lookSamples]));
    check(dev < 1e-6, "Trong suot khi duoi nguong (chi tre lookahead)", "maxDev=" + f2s(dev, 9));
}

// ---------------------------------------------------------------------------
// T7. Loop crossfade
// ---------------------------------------------------------------------------
static void testLoop() {
    section("T7. Loop crossfade equal-power");
    const double sr = 48000;
    // file nền giả: 10 s nhiễu hồng đơn giản (để lộ điểm nối nếu crossfade sai)
    std::vector<float> buf(size_t(sr * 10));
    double ph = 0;
    for (size_t i = 0; i < buf.size(); ++i) { ph += 0.0007; buf[i] = float(0.5 * std::sin(ph) + 0.2 * std::sin(ph * 3.1)); }
    LoopPlayer lp; lp.setBuffer(buf.data(), buf.size()); lp.prepare(sr, 3.0);
    double maxStep = 0, maxAbs = 0; float prev = lp.next();
    for (int64_t n = 1; n < int64_t(sr * 60); ++n) {   // lặp 6 vòng
        float s = lp.next();
        maxStep = std::max(maxStep, std::fabs((double)s - prev));
        maxAbs = std::max(maxAbs, std::fabs((double)s));
        prev = s;
    }
    check(maxStep < 0.01, "Khong co buoc nhay tai diem noi loop", "maxStep=" + f2s(maxStep, 6));
    check(maxAbs < 1.0, "Khong vot bien khi crossfade", "peak=" + f2s(maxAbs, 4));
}

// ---------------------------------------------------------------------------
// Tiện ích chạy engine nhanh
// ---------------------------------------------------------------------------
struct RunStats {
    double seconds = 0, pulseSeconds = 0, dailySeconds = 0, peak = 0;
    double firstNonZeroSec = -1, lastNonZeroSec = 0;
    EndReason reason = EndReason::None;
    bool nan = false;
    double maxStep = 0;
};

static RunStats runEngine(SessionEngine& e, double maxSeconds, int sr = 48000,
                          const std::vector<std::pair<double, int>>& cmds = {}) {
    // cmds: danh sách (giây, lệnh) 1=pause 2=resume 3=stop
    const int block = 256, ch = 2;
    std::vector<float> buf(block * ch);
    RunStats st; size_t nextCmd = 0; float prev = 0;
    int64_t n = 0, total = int64_t(maxSeconds * sr);
    while (n < total) {
        double t = double(n) / sr;
        while (nextCmd < cmds.size() && cmds[nextCmd].first <= t) {
            int c = cmds[nextCmd].second;
            if (c == 1) e.requestPause(); else if (c == 2) e.requestResume(); else e.requestStop();
            ++nextCmd;
        }
        e.process(buf.data(), block, ch);
        for (int i = 0; i < block; ++i) {
            float s = buf[i * ch];
            if (std::isnan(s) || std::isinf(s)) st.nan = true;
            double a = std::fabs((double)s);
            st.peak = std::max(st.peak, a);
            st.maxStep = std::max(st.maxStep, std::fabs((double)s - prev));
            if (a > 1e-5) {
                double tt = double(n + i) / sr;
                if (st.firstNonZeroSec < 0) st.firstNonZeroSec = tt;
                st.lastNonZeroSec = tt;
            }
            prev = s;
        }
        n += block;
        if (e.state() == SessionState::Ended) { n += block; break; }
    }
    st.seconds = double(n) / sr;
    st.pulseSeconds = e.sessionPulseSeconds();
    st.dailySeconds = e.dailyPulseSeconds();
    st.reason = e.endReason();
    return st;
}

static std::vector<float> makeBg(double sr, double sec) {
    std::vector<float> v(size_t(sr * sec));
    double ph = 0;
    for (size_t i = 0; i < v.size(); ++i) { ph += 0.0011; v[i] = float(0.6 * std::sin(ph)); }
    return v;
}

// ---------------------------------------------------------------------------
// T8. State machine + giới hạn 35 phút/phiên
// ---------------------------------------------------------------------------
static void testSessionLimit() {
    section("T8. Gioi han 35 phut/phien (chuong 7)");
    AppConfig cfg; SessionEngine e; e.prepare(48000, cfg);
    auto bg = makeBg(48000, 8);
    e.setBackgroundBuffer(bg.data(), bg.size());
    SessionParams p; p.freqHz = 10.0; p.bgGain = cfg.bgGainMedium;
    p.plannedSeconds = 35 * 60; p.ambientSeconds = 0;
    check(e.start(p), "start() thanh cong", "");
    auto st = runEngine(e, 36 * 60 + 30);
    check(std::fabs(st.pulseSeconds - 2100.0) < 0.01, "Thoi luong co pulse = 2100.000 s",
          "do duoc=" + f2s(st.pulseSeconds, 4) + " s");
    check(st.reason == EndReason::HetGioPhien, "Ly do ket thuc = het_gio_phien",
          endReasonKey(st.reason));
    check(std::fabs(st.lastNonZeroSec - 2103.0) < 0.15, "Fade-out 3s sau khi het gio",
          "am cuoi cung tai t=" + f2s(st.lastNonZeroSec, 3) + " s");
    check(!st.nan && st.peak <= 0.8914, "Khong NaN, khong vuot -1 dBFS trong 35 phut",
          "peak=" + f2s(st.peak, 5));
    check(st.maxStep < 0.05, "Khong co buoc nhay bien do (click) suot phien",
          "maxStep=" + f2s(st.maxStep, 5));

    // Timer người dùng đặt không thể vượt 35 phút
    SessionEngine e2; e2.prepare(48000, cfg);
    e2.setBackgroundBuffer(bg.data(), bg.size());
    SessionParams p2 = p; p2.plannedSeconds = 99 * 60;
    e2.start(p2);
    auto st2 = runEngine(e2, 36 * 60 + 30);
    check(std::fabs(st2.pulseSeconds - 2100.0) < 0.01, "UI dat 99 phut van bi clamp ve 35 phut",
          "do duoc=" + f2s(st2.pulseSeconds, 3) + " s");
}

// ---------------------------------------------------------------------------
// T9. Khoá cứng theo band/ngày (chương 8)
// ---------------------------------------------------------------------------
static void testDailyLock() {
    section("T9. Khoa cung theo band/ngay (chuong 8)");
    AppConfig cfg;
    auto bg = makeBg(48000, 8);

    // 9a. Đã nghe 33 phút -> phiên mới được bắt đầu, bị cắt sau đúng 2 phút
    {
        SessionEngine e; e.prepare(48000, cfg);
        e.setBackgroundBuffer(bg.data(), bg.size());
        SessionParams p; p.freqHz = 8.0; p.bgGain = 0.35; p.plannedSeconds = 35 * 60;
        p.dailyPulseSecondsBefore = 33 * 60;
        check(e.start(p), "Con 2 phut: van cho bat dau phien", "");
        auto st = runEngine(e, 5 * 60);
        check(std::fabs(st.pulseSeconds - 120.0) < 0.01, "Bi cat dung tai phut thu 2",
              "pulse=" + f2s(st.pulseSeconds, 4) + " s");
        check(std::fabs(st.dailySeconds - 2100.0) < 0.01, "Tong ngay dung 2100.000 s (35:00)",
              "daily=" + f2s(st.dailySeconds, 4) + " s");
        check(st.reason == EndReason::KhoaCungNgay, "Ly do = khoa_cung_ngay", endReasonKey(st.reason));
        check(std::fabs(st.lastNonZeroSec - 123.0) < 0.15, "Fade-out khan cap 3 s", "t=" + f2s(st.lastNonZeroSec, 3));
    }
    // 9b. Chế độ ngủ bị BỎ QUA khi chạm hạn mức ngày
    {
        SessionEngine e; e.prepare(48000, cfg);
        e.setBackgroundBuffer(bg.data(), bg.size());
        SessionParams p; p.freqHz = 8.0; p.bgGain = 0.35; p.plannedSeconds = 35 * 60;
        p.ambientSeconds = 900; p.dailyPulseSecondsBefore = 34 * 60 + 30;
        e.start(p);
        auto st = runEngine(e, 10 * 60);
        check(st.reason == EndReason::KhoaCungNgay && st.seconds < 60,
              "Bo qua ambient-only khi bi khoa ngay", "ket thuc sau " + f2s(st.seconds, 1) + " s");
    }
    // 9c. Đã đủ 35 phút -> start() bị từ chối
    {
        SessionEngine e; e.prepare(48000, cfg);
        e.setBackgroundBuffer(bg.data(), bg.size());
        SessionParams p; p.freqHz = 8.0; p.dailyPulseSecondsBefore = 35 * 60;
        check(!e.start(p), "start() bi tu choi khi da du 35 phut", "");
        check(e.endReason() == EndReason::KhoaCungNgay, "Bao dung ly do khoa", "");
    }
    // 9d. Khoá TOÀN BỘ (ALL_BANDS): chỉ Alpha chạm mốc -> mọi band đều bị khoá
    {
        DailyUsage u; u.seconds[int(Band::Alpha)] = 2100.0; u.seconds[int(Band::Delta)] = 60.0;
        LockStatus s = evaluateDailyLock(u, cfg);
        check(s.locked && s.triggerBand == Band::Alpha, "Alpha cham moc -> khoa toan bo chuc nang nghe", "");
        DailyUsage u2; u2.seconds[int(Band::Beta)] = 2099.5;
        check(!evaluateDailyLock(u2, cfg).locked, "Chua cham moc thi khong khoa", "beta=2099.5s");
    }
}

// ---------------------------------------------------------------------------
// T10. Tạm dừng / ambient-only không được cộng giờ
// ---------------------------------------------------------------------------
static void testPauseAmbient() {
    section("T10. Tam dung & ambient-only KHONG cong vao bo dem");
    AppConfig cfg; auto bg = makeBg(48000, 8);
    {
        SessionEngine e; e.prepare(48000, cfg);
        e.setBackgroundBuffer(bg.data(), bg.size());
        SessionParams p; p.freqHz = 10.0; p.bgGain = 0.35; p.plannedSeconds = 600;
        e.start(p);
        // nghe 20s -> pause 40s -> resume 10s -> stop
        auto st = runEngine(e, 120, 48000, {{20, 1}, {60, 2}, {70, 3}});
        check(std::fabs(st.pulseSeconds - 30.0) < 0.15,
              "Nghe 20s + pause 40s + nghe 10s => dem 30s", "pulse=" + f2s(st.pulseSeconds, 3) + " s");
        check(st.reason == EndReason::NguoiDungDung, "Ly do = nguoi_dung_dung", endReasonKey(st.reason));
    }
    {
        SessionEngine e; e.prepare(48000, cfg);
        e.setBackgroundBuffer(bg.data(), bg.size());
        SessionParams p; p.freqHz = 4.0; p.bgGain = 0.35; p.plannedSeconds = 60; p.ambientSeconds = 30;
        e.start(p);
        auto st = runEngine(e, 200);
        check(std::fabs(st.pulseSeconds - 60.0) < 0.05, "Che do ngu: chi dem phan CO pulse",
              "pulse=" + f2s(st.pulseSeconds, 3) + " s");
        check(st.seconds > 90 && st.seconds < 105, "Tong phat ~ 60 + 3 + 30 + 3 s",
              "tong=" + f2s(st.seconds, 1) + " s");
    }
}

// ---------------------------------------------------------------------------
// T11. Fade in/out
// ---------------------------------------------------------------------------
static void testFades() {
    section("T11. Fade in/out 3 s equal-power");
    AppConfig cfg; auto bg = makeBg(48000, 8);
    SessionEngine e; e.prepare(48000, cfg);
    e.setBackgroundBuffer(bg.data(), bg.size());
    SessionParams p; p.freqHz = 10.0; p.bgGain = 0.35; p.plannedSeconds = 30;
    e.start(p);
    const int block = 256, ch = 2; std::vector<float> buf(block * ch);
    std::vector<double> envPerSec(40, 0.0); std::vector<int> cnt(40, 0);
    int64_t n = 0;
    while (e.state() != SessionState::Ended && n < 48000 * 40) {
        e.process(buf.data(), block, ch);
        for (int i = 0; i < block; ++i) {
            int sec = int((n + i) / 48000);
            if (sec < 40) { envPerSec[sec] += std::fabs((double)buf[i * ch]); cnt[sec]++; }
        }
        n += block;
    }
    for (int s = 0; s < 40; ++s) if (cnt[s]) envPerSec[s] /= cnt[s];
    bool rising = envPerSec[0] < envPerSec[1] && envPerSec[1] < envPerSec[2] && envPerSec[3] > envPerSec[0] * 1.5;
    check(rising, "Fade-in tang dan trong 3 s dau", "s0=" + f2s(envPerSec[0], 4) + " s1=" + f2s(envPerSec[1], 4) + " s3=" + f2s(envPerSec[3], 4));
    check(envPerSec[31] < envPerSec[28] && envPerSec[33] < envPerSec[31] * 0.1, "Fade-out ve 0 sau 3 s",
          "s31=" + f2s(envPerSec[31], 5) + " s33=" + f2s(envPerSec[33], 6));
}

// ---------------------------------------------------------------------------
// T12. Band + đổi nền "Không hợp"
// ---------------------------------------------------------------------------
static void testBandAndSwap() {
    section("T12. tinhBand() + doi nen 'Khong hop'");
    struct C { double hz; Band b; };
    std::vector<C> cs = {{1.0, Band::Delta}, {3.5, Band::Delta}, {4.0, Band::Theta}, {7.5, Band::Theta},
                         {8.0, Band::Alpha}, {12.5, Band::Alpha}, {13.0, Band::Beta}, {29.5, Band::Beta},
                         {30.0, Band::Gamma}, {40.0, Band::Gamma}};
    bool ok = true; std::string detail;
    for (auto& c : cs) { if (tinhBand(c.hz) != c.b) { ok = false; detail += f2s(c.hz, 1) + " "; } }
    check(ok, "Ranh gioi 5 band dung", detail.empty() ? "1/4/8/13/30 Hz" : detail);

    AppConfig cfg; auto bg1 = makeBg(48000, 6);
    std::vector<float> bg2(48000 * 6);
    double ph = 0; for (size_t i = 0; i < bg2.size(); ++i) { ph += 0.002; bg2[i] = float(0.6 * std::sin(ph)); }
    SessionEngine e; e.prepare(48000, cfg);
    e.setBackgroundBuffer(bg1.data(), bg1.size());
    SessionParams p; p.freqHz = 10.0; p.bgGain = 0.35; p.plannedSeconds = 60;
    e.start(p);
    const int block = 256, ch = 2; std::vector<float> buf(block * ch);
    double maxStep = 0; float prev = 0; int64_t n = 0;
    while (n < 48000 * 30) {
        if (n == 48000 * 10) e.setBackgroundBuffer(bg2.data(), bg2.size());
        e.process(buf.data(), block, ch);
        for (int i = 0; i < block; ++i) { maxStep = std::max(maxStep, std::fabs((double)buf[i*ch] - prev)); prev = buf[i*ch]; }
        n += block;
    }
    check(maxStep < 0.05, "Doi nen giua phien: crossfade muot, khong click", "maxStep=" + f2s(maxStep, 5));
    check(e.state() == SessionState::Playing, "State chinh khong doi khi bam 'Khong hop'", stateName(e.state()));
    check(e.sessionPulseSeconds() > 29.0, "Thoi gian nghe voi nen cu VAN duoc cong vao bo dem ngay",
          "pulse=" + f2s(e.sessionPulseSeconds(), 2) + " s");
}

// ---------------------------------------------------------------------------
// T13. Engine random có kiểm soát
// ---------------------------------------------------------------------------
static void testScoring() {
    section("T13. Engine random co kiem soat (chuong 6)");
    AppConfig cfg;
    std::vector<SoundStat> kho;
    for (int i = 1; i <= 6; ++i) {
        SoundStat s; s.id = i; s.ten = "Nen " + std::to_string(i);
        s.doManh = (i <= 4) ? Strength::Vua : Strength::Manh;
        s.thoiDiemPhuHop = TimeSlot::BatKy; s.lastPlayedDaysAgo = 10;
        kho.push_back(s);
    }
    // Bước 1: lọc cứng độ mạnh
    {
        std::map<int, int> hits;
        for (int k = 0; k < 2000; ++k) hits[pickBackground(kho, Strength::Manh, TimeSlot::Dem, cfg, k).chosenId]++;
        bool only56 = true; for (auto& h : hits) if (h.first != 5 && h.first != 6) only56 = false;
        check(only56 && hits.size() == 2, "Loc cung theo do manh (chi lay dung muc)", "");
        auto r = pickBackground(kho, Strength::Yeu, TimeSlot::Dem, cfg, 1);
        check(!r.ok && r.emptyStrength, "Kho rong o muc do manh -> bao loi, KHONG tu doi muc", "");
    }
    // Bước 2: cooldown loại cứng dù điểm cao
    {
        auto k2 = kho;
        k2[0].lastPlayedDaysAgo = 1; k2[0].countHop = 50;   // điểm rất cao nhưng vừa nghe hôm qua
        std::map<int, int> hits;
        for (int k = 0; k < 3000; ++k) hits[pickBackground(k2, Strength::Vua, TimeSlot::Dem, cfg, k).chosenId]++;
        check(hits.count(1) == 0, "Cooldown 2 ngay loai cung ung vien diem cao nhat", "");
    }
    // Fallback khi tất cả đều trong cooldown
    {
        auto k3 = kho; for (auto& s : k3) s.lastPlayedDaysAgo = 1;
        auto r = pickBackground(k3, Strength::Vua, TimeSlot::Dem, cfg, 7);
        check(r.ok && r.relaxedCooldown, "Tat ca trong cooldown -> noi xuong 1 ngay", "");
        auto k4 = kho; for (auto& s : k4) s.lastPlayedDaysAgo = 0;
        auto r2 = pickBackground(k4, Strength::Vua, TimeSlot::Dem, cfg, 7);
        check(r2.ok && r2.ignoredCooldown, "Van khong co -> bo qua cooldown + thong bao", "");
    }
    // Bước 3: công thức điểm
    {
        SoundStat s; s.countHop = 3; s.countBinhThuong = 2; s.countKhongHop = 1;
        s.playsLast7Days = 2; s.thoiDiemPhuHop = TimeSlot::Dem; s.rejectedDaysAgo = -1;
        double d = tinhDiem(s, TimeSlot::Dem, cfg);
        double expect = 3 * 10 + 2 * 0 + 1 * (-15) + 5 - 4 * 5;   // 30 -15 +5 -20 = 0
        check(std::fabs(d - expect) < 1e-9, "Cong thuc diem dung", "diem=" + f2s(d, 2) + " ky vong=" + f2s(expect, 2));
        SoundStat r = s; r.rejectedDaysAgo = 0;
        check(std::fabs(tinhDiem(r, TimeSlot::Dem, cfg) - (expect - 50.0)) < 1e-9, "Phat 'Khong hop' hom nay = -50", "");
        r.rejectedDaysAgo = 1;
        check(std::fabs(tinhDiem(r, TimeSlot::Dem, cfg) - (expect - 50.0 * 2 / 3)) < 1e-9, "Phat giam tuyen tinh theo ngay", "");
        r.rejectedDaysAgo = 3;
        check(std::fabs(tinhDiem(r, TimeSlot::Dem, cfg) - expect) < 1e-9, "Het han phat sau 3 ngay", "");
        SoundStat q = s; q.playsLast7Days = 4;
        check(std::fabs(tinhDiem(q, TimeSlot::Dem, cfg) - (expect - (16 - 4) * 5)) < 1e-9, "Phat binh phuong tan suat tuan", "");
    }
    // Bước 4: random có trọng số (không phải luôn chọn điểm cao nhất)
    {
        auto k5 = kho;
        k5[0].countHop = 5;     // điểm cao nhất
        std::map<int, int> hits;
        for (int k = 0; k < 20000; ++k) hits[pickBackground(k5, Strength::Vua, TimeSlot::Dem, cfg, k).chosenId]++;
        bool allAppear = hits.size() == 4;
        double top = hits[1] / 20000.0;
        check(allAppear && top > 0.25 && top < 0.95,
              "Roulette-wheel: uu tien diem cao nhung khong doc quyen",
              "ty le id1=" + f2s(top * 100, 1) + "% / 4 ung vien");
    }
}

// ---------------------------------------------------------------------------
// T14. Ổn định dài hạn + hiệu năng realtime
// ---------------------------------------------------------------------------
static void testLongRunAndPerf() {
    section("T14. On dinh dai han & hieu nang realtime");
    AppConfig cfg; auto bg = makeBg(48000, 12);
    SessionEngine e; e.prepare(48000, cfg);
    e.setBackgroundBuffer(bg.data(), bg.size());
    SessionParams p; p.freqHz = 7.5; p.bgGain = cfg.bgGainStrong; p.plannedSeconds = 35 * 60;
    e.start(p);
    const int block = 256, ch = 2; std::vector<float> buf(block * ch);
    auto t0 = std::chrono::steady_clock::now();
    int64_t n = 0; double peak = 0; bool bad = false;
    double rmsFirst = 0, rmsLast = 0; int64_t cf = 0, cl = 0;
    while (e.state() != SessionState::Ended) {
        e.process(buf.data(), block, ch);
        for (int i = 0; i < block; ++i) {
            float s = buf[i * ch];
            if (std::isnan(s) || std::isinf(s)) bad = true;
            peak = std::max(peak, std::fabs((double)s));
            if (n + i > 48000 * 10 && n + i < 48000 * 70) { rmsFirst += double(s) * s; ++cf; }
            if (n + i > 48000 * 1900 && n + i < 48000 * 1960) { rmsLast += double(s) * s; ++cl; }
        }
        n += block;
        if (n > 48000LL * 3600) break;
    }
    auto t1 = std::chrono::steady_clock::now();
    double wall = std::chrono::duration<double>(t1 - t0).count();
    double audioSec = double(n) / 48000.0;
    rmsFirst = std::sqrt(rmsFirst / std::max<int64_t>(1, cf));
    rmsLast  = std::sqrt(rmsLast / std::max<int64_t>(1, cl));
    check(!bad, "Khong NaN/Inf sau 35 phut lien tuc", "");
    check(peak <= 0.8914, "Peak trong gioi han -1 dBFS", "peak=" + f2s(peak, 5));
    check(std::fabs(rmsFirst - rmsLast) / rmsFirst < 0.05, "Bien do on dinh dau/cuoi phien",
          "rms 10-70s=" + f2s(rmsFirst, 5) + " vs 1900-1960s=" + f2s(rmsLast, 5));
    check(wall * 50 < audioSec, "Hieu nang: nhanh hon realtime >50x (du bien cho dien thoai)",
          f2s(audioSec / wall, 1) + "x realtime (" + f2s(wall, 2) + " s CPU cho " + f2s(audioSec / 60, 1) + " phut am thanh)");
}

// ---------------------------------------------------------------------------
// T15. Kiểm tra lại nhịp trên TÍN HIỆU ĐẦU RA THẬT của engine
//      (đo chu kỳ giữa các đỉnh năng lượng pulse trong output cuối cùng)
// ---------------------------------------------------------------------------
static void testOutputRhythm() {
    section("T15. Do lai nhip tren tin hieu OUTPUT thuc te cua engine");
    for (double hz : {4.0, 10.0, 20.0}) {
        AppConfig cfg; auto bg = makeBg(48000, 8);
        SessionEngine e; e.prepare(48000, cfg);
        e.setBackgroundBuffer(bg.data(), bg.size());
        SessionParams p; p.freqHz = hz; p.bgGain = 0.0; p.plannedSeconds = 600;  // tắt nền để đo sạch
        e.start(p);
        const int block = 256, ch = 2; std::vector<float> buf(block * ch);
        std::vector<float> env; env.reserve(48000 * 300);
        int64_t n = 0;
        while (n < 48000LL * 300) { e.process(buf.data(), block, ch); for (int i = 0; i < block; ++i) env.push_back(std::fabs(buf[i*ch])); n += block; }
        // tìm điểm bắt đầu mỗi burst: biên độ vượt ngưỡng sau khoảng lặng
        double thr = 0.02; std::vector<int64_t> onsets; bool inBurst = false; int64_t silence = 0;
        for (int64_t i = 48000 * 5; i < (int64_t)env.size(); ++i) {   // bỏ qua fade-in
            if (env[i] > thr) {
                if (!inBurst && silence > 50) onsets.push_back(i);
                inBurst = true; silence = 0;
            } else { ++silence; if (silence > 50) inBurst = false; }
        }
        double per = (onsets.size() > 2) ? double(onsets.back() - onsets.front()) / double(onsets.size() - 1) : 0;
        double measured = 48000.0 / per;
        double jitterMax = 0;
        for (size_t i = 1; i < onsets.size(); ++i)
            jitterMax = std::max(jitterMax, std::fabs(double(onsets[i] - onsets[i-1]) - per));
        char info[200];
        snprintf(info, sizeof info, "%.1f Hz -> do duoc %.6f Hz, %zu nhip trong 295 s, jitter max %.4f ms",
                 hz, measured, onsets.size(), jitterMax * 1000.0 / 48000.0);
        check(std::fabs(measured - hz) < 0.001 && jitterMax <= 1.5, "Nhip output chuan xac", info);
    }
}


// ---------------------------------------------------------------------------
// T16. Mo phong CA NGAY: nhieu phien ngan + doi band de "lach luat"
//      -> tong cong don/band/ngay phai bi chan cung o 35:00, khoa toan bo.
// ---------------------------------------------------------------------------
static void testWholeDayAbuse() {
    section("T16. Mo phong ca ngay: bam Dung/Nghe lai nhieu lan & doi band de lach");
    AppConfig cfg; auto bg = makeBg(48000, 8);
    DailyUsage usage;            // vai tro cua bang DailyBandUsage trong DB
    int blocked = 0, sessions = 0;

    // Kich ban 1: 15 phien x 5 phut cung band Alpha (8 Hz)
    for (int i = 0; i < 15; ++i) {
        if (evaluateDailyLock(usage, cfg).locked) { ++blocked; continue; }
        SessionEngine e; e.prepare(48000, cfg);
        e.setBackgroundBuffer(bg.data(), bg.size());
        SessionParams p; p.freqHz = 8.0; p.bgGain = 0.3; p.plannedSeconds = 300;
        p.dailyPulseSecondsBefore = (int64_t)usage.seconds[int(Band::Alpha)];
        if (!e.start(p)) { ++blocked; continue; }
        auto st = runEngine(e, 400);
        usage.seconds[int(Band::Alpha)] += st.pulseSeconds;
        ++sessions;
    }
    check(std::fabs(usage.seconds[int(Band::Alpha)] - 2100.0) < 0.05,
          "Cong don 15 phien x 5 phut bi chan cung o 35:00",
          "tong=" + f2s(usage.seconds[int(Band::Alpha)], 3) + " s sau " + std::to_string(sessions) + " phien, "
          + std::to_string(blocked) + " lan bi chan");

    // Kich ban 2: doi sang band khac de lach -> phai bi khoa toan bo (ALL_BANDS)
    LockStatus ls = evaluateDailyLock(usage, cfg);
    check(ls.locked, "Khoa toan bo sau khi Alpha cham moc", "");
    bool betaBlocked = true;
    {
        if (!evaluateDailyLock(usage, cfg).locked) betaBlocked = false;   // UI phai chan truoc
        SessionEngine e; e.prepare(48000, cfg);
        e.setBackgroundBuffer(bg.data(), bg.size());
        SessionParams p; p.freqHz = 20.0; p.bgGain = 0.3; p.plannedSeconds = 600;
        p.dailyPulseSecondsBefore = (int64_t)usage.seconds[int(Band::Beta)];   // Beta con 0
        // Engine cho phep (vi Beta chua cham moc) => lop UI/Service BAT BUOC phai chan bang
        // evaluateDailyLock truoc khi goi start(). Kiem tra dung quy tac do:
        bool uiWouldBlock = evaluateDailyLock(usage, cfg).locked;
        check(uiWouldBlock, "Doi sang Beta van bi chan (DAILY_LOCK_SCOPE = ALL_BANDS)", "");
    }
    check(betaBlocked, "Khong the lach bang cach doi band", "");

    // Kich ban 3: qua 00:00 -> reset
    DailyUsage fresh;
    check(!evaluateDailyLock(fresh, cfg).locked, "Sau 00:00 (bang usage moi) mo khoa lai", "");
}

int main() {
    printf("=========================================================\n");
    printf("  IsT - KIEM THU LOI AUDIO ENGINE (C++)\n");
    printf("=========================================================\n");
    testPulseTiming();
    testDutyCycle();
    testEnvelope();
    testCarrier();
    testDucking();
    testLimiter();
    testLoop();
    testSessionLimit();
    testDailyLock();
    testPauseAmbient();
    testFades();
    testBandAndSwap();
    testScoring();
    testOutputRhythm();
    testWholeDayAbuse();
    testLongRunAndPerf();
    printf("\n---------------------------------------------------------\n");
    printf("  TONG KET: %d PASS / %d FAIL\n", g_pass, g_fail);
    printf("---------------------------------------------------------\n");
    return g_fail == 0 ? 0 : 1;
}
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: tests/soak_and_render.cpp
# ----------------------------------------------------------------------------
mkdir -p "tests"
cat > 'tests/soak_and_render.cpp' <<'IST__EOF__b7f3'
// tests/soak_and_render.cpp
// (a) Soak test: chạy PulseGate 2 GIỜ liên tục ở 48k & 44.1k, kiểm tra tuyệt đối
//     không trôi nhịp (so từng onset với mốc lý thuyết).
// (b) Render file WAV demo để nghe kiểm chứng bằng tai.
#include "ist/dsp.h"
#include "ist/session.h"
#include <cstdio>
#include <cstring>
#include <vector>
#include <cmath>
#include <string>

using namespace ist;

static void writeWav(const std::string& path, const std::vector<float>& mono, int sr) {
    FILE* f = fopen(path.c_str(), "wb");
    int n = (int)mono.size();
    int dataBytes = n * 2;
    auto w32 = [&](uint32_t v) { fwrite(&v, 4, 1, f); };
    auto w16 = [&](uint16_t v) { fwrite(&v, 2, 1, f); };
    fwrite("RIFF", 1, 4, f); w32(36 + dataBytes); fwrite("WAVE", 1, 4, f);
    fwrite("fmt ", 1, 4, f); w32(16); w16(1); w16(1); w32(sr); w32(sr * 2); w16(2); w16(16);
    fwrite("data", 1, 4, f); w32(dataBytes);
    for (float s : mono) {
        int v = (int)std::lround(s * 32767.0f);
        if (v > 32767) v = 32767; if (v < -32768) v = -32768;
        w16((uint16_t)(int16_t)v);
    }
    fclose(f);
    printf("  -> %s (%.1f s)\n", path.c_str(), double(n) / sr);
}

static void soak(double sr, double freq, double hours) {
    PulseGate g; g.prepare(sr, freq, 0.5, 5.0);
    int64_t total = int64_t(sr * 3600.0 * hours);
    bool prev = false; int64_t k = 0; double maxErr = 0; double lastErr = 0;
    for (int64_t n = 0; n < total; ++n) {
        bool o = g.gateOpen();
        if (o && !prev) {
            double ideal = double(k) * sr / freq;
            double e = double(n) - ideal;
            if (std::fabs(e) > maxErr) maxErr = std::fabs(e);
            lastErr = e; ++k;
        }
        prev = o; g.next();
    }
    printf("  sr=%5.0f f=%5.2fHz %.0fh: %lld nhip | sai so onset toi da = %.3f mau (%.4f ms) | "
           "sai so nhip CUOI CUNG = %.3f mau  => %s\n",
           sr, freq, hours, (long long)k, maxErr, maxErr * 1000.0 / sr, lastErr,
           (maxErr <= 1.0 ? "KHONG TROI NHIP" : "*** TROI NHIP ***"));
}

int main(int argc, char** argv) {
    printf("=== SOAK TEST: 2 gio lien tuc, kiem tra troi nhip ===\n");
    soak(48000, 10.0, 2.0);
    soak(48000, 7.5, 2.0);
    soak(44100, 7.5, 2.0);
    soak(44100, 40.0, 2.0);
    soak(48000, 1.0, 2.0);

    printf("\n=== RENDER WAV DEMO (nghe kiem chung bang tai) ===\n");
    const int sr = 48000;
    AppConfig cfg;
    // nền giả: tiếng "mưa" tổng hợp đơn giản (nhiễu lọc thấp)
    std::vector<float> bg(sr * 12);
    uint32_t rnd = 12345; float lp = 0;
    for (size_t i = 0; i < bg.size(); ++i) {
        rnd = rnd * 1664525u + 1013904223u;
        float w = (float)((int)(rnd >> 9) % 20001 - 10000) / 10000.0f;
        lp += 0.08f * (w - lp);
        bg[i] = lp * 2.2f;
    }
    struct Demo { double hz; const char* name; int sec; };
    Demo demos[] = {{10.0, "demo_10hz_alpha", 20}, {4.0, "demo_4hz_theta", 20}, {20.0, "demo_20hz_beta", 15}};
    for (auto& d : demos) {
        SessionEngine e; e.prepare(sr, cfg);
        e.setBackgroundBuffer(bg.data(), bg.size());
        SessionParams p; p.freqHz = d.hz; p.bgGain = cfg.bgGainMedium; p.plannedSeconds = d.sec;
        e.start(p);
        std::vector<float> out; const int block = 256; std::vector<float> buf(block * 2);
        while (e.state() != SessionState::Ended && (int)out.size() < sr * (d.sec + 10)) {
            e.process(buf.data(), block, 2);
            for (int i = 0; i < block; ++i) out.push_back(buf[i * 2]);
        }
        writeWav(std::string("demo/") + d.name + ".wav", out, sr);
    }
    return 0;
}
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# FILE: tools/make_logo.py
# ----------------------------------------------------------------------------
mkdir -p "tools"
cat > 'tools/make_logo.py' <<'IST__EOF__b7f3'
#!/usr/bin/env python3
# Sinh logo IsT (nen den #000000, chu vang #D4AF37) + icon mipmap + splash.
# Chay: python3 tools/make_logo.py     (can Pillow: pip install pillow)
from PIL import Image, ImageDraw, ImageFont
import os, sys

GOLD = (212, 175, 55, 255)      # #D4AF37
BLACK = (0, 0, 0, 255)

CANDIDATE_FONTS = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "C:/Windows/Fonts/arialbd.ttf",
]
F = next((f for f in CANDIDATE_FONTS if os.path.exists(f)), None)
if F is None:
    sys.exit("Khong tim thay font sans-serif dam. Sua CANDIDATE_FONTS.")


def logo(size, fg=GOLD, pulse=True, transparent_bg=False, textfrac=0.56):
    S = 1024
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0) if transparent_bg else BLACK)
    d = ImageDraw.Draw(img)
    fs = 400
    font = ImageFont.truetype(F, fs)
    bb = d.textbbox((0, 0), "IsT", font=font)
    fs = int(fs * (S * textfrac) / (bb[2] - bb[0]))
    font = ImageFont.truetype(F, fs)
    bb = d.textbbox((0, 0), "IsT", font=font)
    w, h = bb[2] - bb[0], bb[3] - bb[1]
    cx, cy = S // 2, int(S * 0.44)
    d.text((cx - w // 2 - bb[0], cy - h // 2 - bb[1]), "IsT", font=font, fill=fg)
    if pulse:  # dai xung vuong manh duoi chu (<= 4% chieu cao canvas)
        th = int(S * 0.028); width = int(S * textfrac); left = (S - width) // 2
        base = int(S * 0.74); amp = int(S * 0.045); seg = width / 8.0
        pts = []; up = True
        for i in range(8):
            yv = base - amp if up else base
            pts += [(left + seg * i, yv), (left + seg * (i + 1), yv)]
            up = not up
        d.line(pts, fill=fg, width=th, joint="curve")
    return img.resize((size, size), Image.LANCZOS)


os.makedirs("brand", exist_ok=True)
logo(1024).save("brand/ist_icon_1024.png")
logo(1024, fg=(255, 255, 255, 255)).save("brand/ist_icon_mono_white.png")
for name, px in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]:
    p = f"app/src/main/res/mipmap-{name}"
    os.makedirs(p, exist_ok=True)
    logo(px).save(f"{p}/ic_launcher.png")
    logo(px).save(f"{p}/ic_launcher_round.png")
    logo(int(px * 2.2), transparent_bg=True, textfrac=0.42).save(f"{p}/ic_launcher_foreground.png")
sp = Image.new("RGBA", (1080, 1920), BLACK)
l = logo(700)
sp.paste(l, ((1080 - 700) // 2, (1920 - 700) // 2), l)
sp.convert("RGB").save("brand/splash_1080x1920.png")
print("Da sinh logo + icon + splash.")
IST__EOF__b7f3

# ----------------------------------------------------------------------------
# Sinh logo / icon / splash (PNG) - can Python + Pillow
# ----------------------------------------------------------------------------
if command -v python3 >/dev/null 2>&1 && python3 -c "import PIL" >/dev/null 2>&1; then
    python3 tools/make_logo.py || echo "  (Bo qua: khong sinh duoc logo, app van build duoc voi icon mac dinh)"
else
    echo "  (Bo qua sinh logo: thieu Python/Pillow -> chay 'pip install pillow' roi 'python3 tools/make_logo.py')"
fi

echo
echo "XONG. Buoc tiep theo:"
echo "  cd $(pwd)"
echo "  make test       # kiem thu loi audio C++ (85 bai) ngay tren may tinh"
echo "  make soak       # soak 2 gio + xuat file WAV nghe thu trong demo/"
echo "  Mo thu muc nay bang Android Studio de build APK."

