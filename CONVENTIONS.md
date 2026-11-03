# CONVENTIONS.md: Kinoite-Spec Kodlama ve Mimari Standartları

Bu belge, `kinoite-spec` projesi için yazılacak tüm Haskell kodlarının ve sistem etkileşimlerinin uyması gereken kuralları tanımlar. Yapay zeka asistanları kod üretirken bu kuralları **kesin bir şekilde** gözetmek zorundadır.

## 1. Mimari Felsefe: Saf Çekirdek, Imperatif Kabuk
- **İş Mantığı Saf Olmalıdır:** `rpm-ostree` ve `flatpak` listelerini karşılaştıran (diff), kararları veren ve sıralayan tüm fonksiyonlar **saf (pure)** olmalıdır. Bu fonksiyonların tip imzalarında asla `IO` bulunamaz.
- **IO Sadece Uçlarda:** Dosya okuma (`yaml`), komut çalıştırma (`typed-process`) ve ekrana yazdırma işlemleri yalnızca uygulamanın en dış kabuğunda (`Main` veya `Runner` modüllerinde) yer alabilir.

## 2. Haskell Kodlama Standartları
- **Kesin Tip İmzaları:** Tüm üst seviye fonksiyonlar, değerler ve veri tipleri açıkça belirtilmiş bir tip imzasına (`type signature`) sahip olmak zorundadır. Tip çıkarımına (type inference) güvenilerek imzasız fonksiyon bırakılamaz.
- **Kısmi Fonksiyonlar Yasaktır:** Programın çökmesine (panic) yol açabilecek `head`, `tail`, `fromJust`, `!!`, `error` ve `undefined` kullanımı kesinlikle yasaktır. Bunların yerine pattern matching, `Maybe` veya `Either` monadları kullanılacaktır.
- **String Yerine Text/ByteString:** Performans ve bellek güvenliği için standart `String` tipi yerine metin işlemlerinde `Data.Text`, dosya/soket okumalarında `Data.ByteString` kullanılacaktır. Gerekirse `OverloadedStrings` eklentisi (pragma) aktif edilecektir.
- **Güçlü Tipler (Newtype):** Farklı ID'lerin karışmasını önlemek için basit metinler yerine sarmalayıcı (wrapper) tipler kullanılacaktır (örnek: `type String` yerine `newtype FlatpakId = FlatpakId Text`).

## 3. Fedora Kinoite ve Sistem Etkileşimi
- **Sudo / Root Varsayımı Yasaktır:** `kinoite-spec` standart bir kullanıcı (user) olarak çalışır. Geliştirilen kodlar asla doğrudan `sudo` çağırmamalıdır. `rpm-ostree` komutları sistem düzeyinde Polkit ile zaten yetkilendirme ister, Flatpak komutları ise duruma göre `--user` veya `--system` bayraklarıyla yönetilecektir.
- **Regex Yerine JSON Parsing:** Sistem araçlarının çıktılarını (stdout) analiz ederken asla RegEx veya düz metin parçalama kullanılmayacaktır. Tüm sistem araçları JSON modunda çağrılacak (`rpm-ostree status --json`, `flatpak list --json`) ve Haskell tarafında `aeson` ile strongly-typed (kesin tipli) olarak ayrıştırılacaktır.
- **Güvenli Komut Çalıştırma:** Harici sistem komutlarını çağırmak için standart `System.Process` yerine her zaman daha güvenli ve modern olan `typed-process` kütüphanesi kullanılacaktır.

## 4. Yapay Zeka (AI) Yönlendirmeleri
- **Adım Adım İlerleme:** AI asistanı, bir özelliği eklemeden önce `ROADMAP.md` dosyasını kontrol etmeli ve sadece o anki aşamanın gerekliliklerini kodlamalıdır. Kapsam dışına çıkmak (scope creep) yasaktır.
- **Bağımlılık Kontrolü:** `kinoite-spec.cabal` dosyasına yeni bir harici paket (dependency) eklenmeden önce mutlaka kullanıcıdan onay alınmalıdır.
- **Güncel Tutma:** Bir aşama başarıyla test edilip tamamlandığında, AI asistanı `ROADMAP.md` içindeki ilgili kutucuğu `[x]` olarak işaretlemeyi teklif etmelidir.
