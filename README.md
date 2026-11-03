# kinoite-spec

Fedora Kinoite sistemlerini deklaratif bir YAML dosyasından yönetmeyi
amaçlayan Haskell tabanlı bir sistem konverjans motoru.

## Durum

Proje şu anda Faz 6 kapsamındadır:

- Konfigürasyon YAML'ını güçlü Haskell tiplerine dönüştürme
- `rpm-ostree status --json` çıktısını ayrıştırma
- `flatpak list --json` çıktısını user/system kurulumlarına ayırma
- Mevcut sistem durumunu temsil eden temel tipler
- Mevcut ve hedef durum arasındaki farkları hesaplama
- `plan --config` komutuyla renkli plan çıktısı üretme
- Kullanıcı onayıyla veya `--yes` ile action yürütme
- Distrobox durumlarını okuma ve eksik kutuları oluşturma planı
- `export` komutuyla mevcut durumu YAML olarak dışa aktarma
- Flatpak `filesystem`, `environment` ve `sockets` override'larını uygulama
- Belirsiz Flatpak kaynakları için uygulama başına `remote` seçimi

Flatpak override örneği:

```yaml
flatpak:
  remotes:
    org.kde.KMines: flathub
  overrides:
    com.example.App:
      filesystem:
        - home
      environment:
        - EDITOR=vim
      sockets:
        - wayland
```

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

Tek binary'yi `~/.local/bin` altına kurmak için:

```bash
cabal install exe:kinoite-spec --installdir="$HOME/.local/bin" --overwrite-policy=always
```

Binary, Distrobox içinde `distrobox-host-exec` üzerinden; Distrobox dışında ise
doğrudan `rpm-ostree`, `flatpak` ve `distrobox` komutları üzerinden çalışır.

## Proje planı

Aşamalar ve kapsamları [ROADMAP.md](ROADMAP.md) dosyasında açıklanmıştır.
