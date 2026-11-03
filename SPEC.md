# SPEC.md: kinoite-spec

## 1. Genel Bakış ve Amaç
`kinoite-spec`, Fedora Kinoite sistemlerini tek bir deklaratif YAML dosyasından yönetmek için geliştirilmiş bir sistem konverjans (uyum) motorudur. Sistem durumunu (`rpm-ostree`, `flatpak` ve `distrobox`) analiz eder, istenen hedef durumla karşılaştırır (diff), yapılması gereken işlemleri kullanıcıya gösterir (`--dry-run`) ve onay verildiğinde sistemi hedeflenen duruma getirir.

---

## 2. Temel Mimari İlkeler
- **Saf İş Mantığı (Pure Core, Imperative Shell):** Karşılaştırma, sıralama ve plan çıkarma adımlarında hiçbir `IO` işlemi yapılmaz. Sistem durumunu okuma ve komutları yürütme işlemleri izole kabuk katmanında tutulur.
- **İdempotentlik:** Bir spec dosyası sisteme defalarca uygulansa bile, sistem zaten hedeflenen durumdaysa hiçbir yan etki üretilmez (`no-op`).
- **Önce Güvenlik:** Kullanıcı açıkça onay vermeden veya `--yes` bayrağı geçilmeden sistemde hiçbir paket/katman eklenemez veya kaldırılamaz.

---

## 3. Konfigürasyon Şeması (`spec.yaml`)

```yaml
version: 1

ostree:
  layered_packages:
    - zsh
    - git
    - tmux

flatpak:
  user:
    - com.spotify.Client
    - com.visualstudio.code
    - md.obsidian.Obsidian
  system:
    - org.mozilla.firefox
  overrides:
    com.spotify.Client:
      filesystem:
        - home
      environment:
        - EDITOR=vim
      sockets:
        - wayland

distrobox:
  - name: dev-box
    image: registry.fedoraproject.org/fedora-toolbox:latest
    home: ~/Dev
```

---

## 4. Sistem İnceleme & Entegrasyon Noktaları

| Katman | Tespit Komutu | Beklenen Format | Çıktı Türü |
|---|---|---|---|
| `rpm-ostree` | `rpm-ostree status --json` | JSON | `deployments[0].requested-packages` |
| `flatpak` | `flatpak list --json` | JSON | `application` ve `installation` |
| `distrobox` | `distrobox list` | Düz Metin / CSV | İsim ve durum satırları |

---

## 5. Komut Satırı Arayüzü (CLI)

```bash
# Sadece farkları ve yürütme planını listeler (varsayılan davranış)
kinoite-spec plan --config spec.yaml

# Farkları uygular (kullanıcıdan onay ister)
kinoite-spec apply --config spec.yaml

# Onay istemeden otomatik uygular (otomasyon/scriptler için)
kinoite-spec apply --config spec.yaml --yes

# Mevcut sistem durumunu okuyup geçerli bir spec.yaml üretir
kinoite-spec export > current-spec.yaml
```

---

## 6. Kapsam Dışı Konular (Non-Goals)
- Kendi paket yöneticisini yazmak (araç sadece `rpm-ostree` ve `flatpak` CLI araçlarını orkestre eder).
- Arka planda çalışan bir `systemd` daemon'ı veya izleme servisi olmak.
- Grafiksel arayüz (GUI) veya Web UI sunmak.
- Root yetkisiyle doğrudan `sudo` çalıştırmak (araç kullanıcı yetkisiyle çalışır; gereken komutlarda `rpm-ostree` zaten Polkit kullanır).

---

## 7. Kullanılacak Haskell Paketleri
- `base >= 4.16 && < 5`
- `text`, `bytestring`, `containers`
- `yaml`, `aeson` (Konfigürasyon ve JSON ayrıştırma)
- `optparse-applicative` (CLI argümanları)
- `typed-process` (Sistem komutlarını güvenli çalıştırma)
- `ansi-terminal` (Renkli diff çıktıları)
