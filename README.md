# kinoite-spec

Fedora Kinoite sistemlerini deklaratif bir YAML dosyasından yönetmeyi
amaçlayan Haskell tabanlı bir sistem konverjans motoru.

## Durum

Proje şu anda Faz 5 kapsamındadır:

- Konfigürasyon YAML'ını güçlü Haskell tiplerine dönüştürme
- `rpm-ostree status --json` çıktısını ayrıştırma
- `flatpak list --json` çıktısını user/system kurulumlarına ayırma
- Mevcut sistem durumunu temsil eden temel tipler
- Mevcut ve hedef durum arasındaki farkları hesaplama
- `plan --config` komutuyla renkli plan çıktısı üretme
- Kullanıcı onayıyla veya `--yes` ile action yürütme

`export` komutu ve Distrobox yönetimi henüz tamamlanmamıştır.

## Gereksinimler

- GHC 9.4 veya üzeri
- Cabal
- Fedora Kinoite üzerinde test için `rpm-ostree` ve `flatpak`

## Derleme ve test

```bash
cabal build
cabal test config-tests
```

Testler gerçek sistem komutlarını çalıştırmaz; örnek JSON çıktılarıyla parser
davranışını doğrular.

## Proje planı

Aşamalar ve kapsamları [ROADMAP.md](ROADMAP.md) dosyasında açıklanmıştır.
