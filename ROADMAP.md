---

### `ROADMAP.md`

```markdown
# ROADMAP.md: kinoite-spec

## Faz 0: Proje Kurulumu ve Altyapı
- [X] Cabal projesini oluştur (`kinoite-spec.cabal`, `app/Main.hs`, `src/`)
- [X] `ghcup` üzerinden GHC 9.4+ ve Cabal ortamını doğrula
- [X] Temel CLI iskeletini `optparse-applicative` ile ayağa kaldır (`--help`, `--version`, `plan`, `apply`)

---

## Faz 1: Tip Modellemesi ve Konfigürasyon Okuma
- [ ] `Src.Types.Spec`: Hedef sistem için cebirsel veri tiplerini (`SystemSpec`, `OstreeSpec`, `FlatpakSpec`) tanımla
- [ ] `Src.Config`: `yaml` ve `aeson` kütüphanelerini kullanarak `spec.yaml` dosyasını `SystemSpec` tipine dönüştür
- [ ] Eksik veya bozuk YAML girdileri için açıklayıcı hata mesajları ekle
- [ ] **Test:** Geçerli ve geçersiz YAML dosyaları ile birim testleri yaz

---

## Faz 2: Sistem Durumunu Okuma (Inspection Layer)
- [ ] `Src.System.Ostree`: `rpm-ostree status --json` çıktısını çalıştırıp `Set PackageName` tipine dönüştür
- [ ] `Src.System.Flatpak`: `flatpak list --json` çıktısını çalıştırıp kurulu ID'leri ayrıştır
- [ ] `Src.Types.CurrentState`: Sistemin o anki durumunu temsil eden birleşik veri tipini oluştur
- [ ] **Test:** Simüle edilmiş (mock) JSON çıktılarıyla parser doğruluğunu test et

---

## Faz 3: Saf Karşılaştırma ve Diff Motoru (Pure Engine)
- [ ] `Src.Types.Action`: Yapılacak işlemleri modelleyen tipleri tanımla:
  - `InstallOstree PackageName` / `RemoveOstree PackageName`
  - `InstallFlatpak FlatpakId Scope` / `RemoveFlatpak FlatpakId Scope`
- [ ] `Src.Engine.Diff`: `CurrentState -> SystemSpec -> [Action]` saf fonksiyonunu implemente et
- [ ] Küme farkı (set difference) mantığını test et:
  - Hedefte olup sistemde olmayanlar -> `Install`
  - Sistemde olup hedefte olmayanlar -> `Remove`
  - İki tarafta da olanlar -> Yok say
- [ ] **Test:** Saf diff motoru için kapsamlı birim testleri (QuickCheck veya Hspec) ekle

---

## Faz 4: Terminal Çıktısı ve Planlama (Dry-Run UX)
- [ ] `Src.UI.Printer`: `[Action]` listesini terminalde renkli ve okunabilir olarak biçimlendir:
  - Yeşil: `+ Kurulacak`
  - Kırmızı: `- Kaldırılacak`
  - Mavi: `~ Değişecek / Güncellenecek`
- [ ] `kinoite-spec plan` komutunu sisteme bağla ve terminalde gerçek diff'i göster
- [ ] Değişiklik yoksa `Sistem senkronize durumda.` mesajı basıp çık

---

## Faz 5: Yürütme ve Konverjans (Action Runner)
- [ ] `Src.Runner`: `[Action]` listesini gerçek sistem komutlarına dönüştür:
  - `flatpak install/uninstall` çağrıları
  - `rpm-ostree install/uninstall` çağrıları
- [ ] Kullanıcı onay mekanizmasını entegre et (`Bu değişiklikler uygulansın mı? [e/H]`)
- [ ] Komutların hata durumlarını (`ExitFailure`) güvenli şekilde yakala ve kullanıcıya bildir
- [ ] `kinoite-spec apply` komutunu doğrula

---

## Faz 6: Gelişmiş Özellikler ve Rafine Etme
- [ ] Distrobox konteyner durumlarını okuma ve `distrobox create` entegrasyonu
- [ ] Flatpak izin geçersiz kılmalarını (`overrides`) destekleme
- [ ] `kinoite-spec export` komutuyla mevcut sistemi tek komutta YAML'a dökme
- [ ] Tek binary çıktısı alıp Distrobox dışından (`~/.local/bin`) sorunsuz çalıştığını doğrulama
