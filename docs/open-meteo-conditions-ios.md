# Open-Meteo Marine Conditions — iOS Entegrasyonu

Sörf spotu seçildiğinde `SpotDetailPresenter`, backend'den gerçek koşulları çekip placeholder Spot'u gerçek veriyle değiştirir. Bu sayede dalga grafiği ve AI özeti otomatik olarak tetiklenir.

---

## Yeni / Değişen Dosyalar

### `Conatus/Model/Spot.swift` _(değişti)_

`WaveSample`'a `directionDegrees: Double` alanı eklendi (varsayılan `0` — mevcut çağrı noktaları değişmedi):

```swift
struct WaveSample: Identifiable {
    let directionDegrees: Double  // swell yönü (derece), yeni alan
    // ... diğer alanlar önceden vardı
}
```

`Spot.placeholder(from:)` içindeki private `placeholderAppearance` → `internal static func appearance(for:)` olarak yeniden adlandırıldı. `Spot.subtitle(from:)` yardımcısı da eklendi. Her ikisi de `SpotConditionsService` tarafından yeniden kullanılır.

---

### `Conatus/Services/SpotConditionsService.swift` _(yeni)_

`SearchService` kalıbını izler: `URLSession` + `async/await`, kendi hata enum'u.

**DTO'lar:** `SpotConditionsDTO`, `SpotConditionsDTO.Current`, `SpotConditionsDTO.Hourly` — backend `SpotConditionsResponse` şemasını birebir yansıtır (snake_case → camelCase `CodingKeys`).

**`dto.makeSpot(from: SpotResult) -> Spot?`:**
- `conditions == nil` (kıta içi / kapsama yok) → `nil` döner, placeholder korunur
- Başarılıda: `Weather`, `Wind`, `[WaveSample]` (ilk 12 slot) oluşturur
- WMO kodu → `WeatherCondition` eşlemesi:

| WMO Kodu | Durum |
|---|---|
| 0 | `.clear` |
| 1–2 | `.partlyCloudy` |
| 3, 45, 48 | `.cloudy` |
| 51–67, 80–82, 95–99 | `.rainy` |
| 71–77, 85–86 | `.cloudy` |
| diğer | `.clear` |

---

### `Conatus/Views/Component/Spot/SpotDetailSheetContainer.swift` _(değişti)_

`SpotDetailPresenter`'a şunlar eklendi:

```swift
private let conditionsService = SpotConditionsService()
private var conditionsTask: Task<Void, Never>?
```

**`select(_ result: SpotResult)` yeni davranışı:**

```
1. Önceki conditionsTask iptal edilir
2. Placeholder Spot anında gösterilir (sheet gecikme olmadan açılır)
3. Arka planda Task başlatılır:
   └─ fetchConditions(spotId:) çağrılır
   └─ Başarı + conditions != nil → makeSpot() ile gerçek Spot oluşturulur
      └─ select(Spot?) çağrılır → WeatherSummarizeGenerator tetiklenir
   └─ conditions == nil (kıta içi) → placeholder korunur, AI özeti çalışmaz
   └─ Ağ hatası → placeholder korunur, sessizce düşer
```

**İptal güvenliği:**
- Yeni spot seçimi önceki `conditionsTask`'ı iptal eder
- Sheet kapatıldığında hem `conditionsTask` hem `summaryTask` iptal edilir
- `CancellationError` sessizce yakalanır

---

## Veri Akışı

```
Kullanıcı spot seçer
      │
      ▼
select(SpotResult)
      │
      ├─ Placeholder Spot → selectedSpot (sheet açılır)
      │
      └─ conditionsTask başlar (arka plan)
              │
              ▼
       GET /v1/spots/{id}/conditions
              │
        ┌─────┴──────┐
        │ başarı     │ hata / inland
        ▼            ▼
   makeSpot()    placeholder korunur
        │
        ▼
   select(Spot)     ← isPlaceholder: false
        │
        ▼
 summarizer.generate()  ← AI özeti tetiklenir
        │
        ▼
 SpotDetailSheetView güncellenir
```

---

## Bağımlılıklar

Yeni bağımlılık yok. `URLSession.shared` kullanılır.
