# RecyclerView for SwiftUI

`RecyclerView`, iOS layihələrində **SwiftUI** daxilində **UIKit** performansı və güclü `UICollectionView` infrastrukturundan istifadə edərək siyahıları (`List` və ya `ScrollView` + `LazyVStack` alternativləri kimi) yüksək performansla render etmək üçün yaradılmış fərdiləşdirilmiş komponentdir.

Xüsusilə böyük məlumat setləri, dinamik hüceyrə hündürlükləri, qarışıq Grid və ya Linear dizaynlar, pagination (sonsuz skrol) və tərs siyahı (`reverseLayout`/`stackFromEnd`) ehtiyacları üçün mükəmməl həlldir.

---

## Özəlliklər (Features)

- ⚡ **Yüksək Performans:** `UICollectionView` və `UIHostingController` inteqrasiyası sayəsində hüceyrələrin təkrar istifadəsi (cell reuse) təmin edilir.
- 📐 **Dinamik Hüceyrə Hündürlüyü:** Hüceyrə daxilindəki SwiftUI mətni və ya kontentinə uyğun olaraq ölçülər avtomatik hesablanır.
- 🔀 **Layout Menecerləri:** Tək sətirlə şaquli/üfüqi siyahı (`linear`) və ya çoxsütunlu tor (`grid`) görünüşünə keçid.
- 🔄 **Tərs Siyahı Dəstəyi:** Çat (Chat) tətbiqləri üçün xüsusi `reverseLayout` və `stackFromEnd` konfiqurasiyaları.
- 📈 **Sonsuz Skrol (Pagination):** Siyahının sonuna yaxınlaşdıqda avtomatik işə düşən ağıllı `onLoadMore` mexanizmi.
- 📱 **Hündürlük Hesablama (Wrap Content):** Kontentin həcminə uyğun olaraq çərçivə hündürlüyünü dinamik müəyyənləşdirə bilir (`calculateWrapHeight`).
- 🛠️ **iOS 16+ Optimizasiyası:** iOS 16 və daha yuxarı versiyalarda yerli `UIHostingConfiguration` strukturundan istifadə edir.

---

## Quraşdırma (Installation)

### Swift Package Manager (SPM)

Layihənizə `Package.swift` faylı vasitəsilə və ya Xcode daxilində birbaşa asılılıq (dependency) olaraq əlavə edə bilərsiniz:

```swift
dependencies: [
    .package(url: "https://github.com/SİZİN_USER_NAME/RecyclerView.git", from: "1.0.0")
]
```

---

## İstifadə Qaydası (Usage)

### 1. Sadə Şaquli Siyahı (Linear Vertical)

```swift
import SwiftUI

struct ItemModel: Identifiable {
    let id = UUID()
    let title: String
    let description: String
}

struct ExampleView: View {
    @State private var items = (1...100).map { ItemModel(title: "Başlıq \($0)", description: "Təsvir mətni bura yazılır...") }
    
    var body: some View {
        RecyclerView(data: items, layout: .linear(orientation: .vertical, spacing: 10)) { item in
            VCornerCard(item: item) // Sizin SwiftUI View
        }
        .onItemClick { index, item in
            print("Klikləndi: \(item.title) (İndeks: \(index))")
        }
    }
}

struct VCornerCard: View {
    let item: ItemModel
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title).font(.headline)
            Text(item.description).font(.subheadline).foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
    }
}
```

### 2. Grid (Tor) Görünüşü və Span Size Lookup

Əgər müəyyən elementlərin bütün sətri tutmasını (məsələn, başlıqlar), digərlərinin isə sütunlara bölünməsini istəyirsinizsə:

```swift
RecyclerView(data: items, layout: .grid(spanCount: 3, spacing: 12, orientation: .vertical)) { item in
    GridCellView(item: item)
}
.spanSizeLookup { item in
    // Əgər element xüsusi bir tipdirsə 3 sütunun hamısını tutsun, yoxsa 1 sütun
    return item.title.contains("Xüsusi") ? 3 : 1
}
```

### 3. Sonsuz Skrol (Load More / Pagination)

Siyahı aşağı çəkildikcə yeni məlumatların yüklənməsi üçün `onLoadMore` modifikatorundan istifadə edin:

```swift
RecyclerView(data: items, layout: .linear(orientation: .vertical, spacing: 8)) { item in
    Text(item.title)
}
.onLoadMore(pageSize: 20) { page, totalItemCount in
    print("Yeni səhifə yüklənir: \(page). Ümumi element: \(totalItemCount)")
    // Serverdən və ya databazadan yeni məlumatları gətirib 'items' massivinə əlavə edin
}
```

### 4. Çat Tətbiqləri üçün Tərs Siyahı (Reverse & Stack From End)

Yeni mesajların aşağıdan yuxarıya doğru düzülməsi və skrolun aşağıdan başlaması üçün:

```swift
RecyclerView(data: messages, layout: .linear(orientation: .vertical, spacing: 8)) { message in
    MessageBubble(message: message)
}
.reverseLayout(true)
.stackFromEnd(true)
```

---

## Struktur Konfiqurasiyası (Modifikatorlar)

`RecyclerView` komponenti tam idarəetmə üçün aşağıdakı zəncirvari funksiyaları dəstəkləyir:

| Modifikator | Tip | Təsvir |
| :--- | :--- | :--- |
| `.onItemClick((Int, Item) -> Void)` | Blok | Siyahıdakı hər hansı elementə kliklədikdə icra olunur. |
| `.onLoadMore(pageSize: Int, (Int, Int) -> Void)` | Blok | Pagination üçün səhifə ölçüsü və yükləmə tətikləyicisi. |
| `.spanSizeLookup((Item) -> Int)` | Blok | Grid rejimində elementin neçə sütun tutacağını təyin edir. |
| `.showsScrollIndicator(Bool)` | Boolean | Skrol xəttinin (indicator) görünüb-görünməməsi. |
| `.reverseLayout(Bool)` | Boolean | Siyahını alt-üst (tərs) çevirir. |
| `.stackFromEnd(Bool)` | Boolean | Siyahını aşağıdan yuxarıya doğru doldurur. |
| `.verticalLayout(RecyclerViewVerticalLayout)` | Enum | `.wrapContent` (hündürlüyü məzmuna görə sıxır) və ya `.matchParent` (ekranı doldurur). |
| `.withAnimation(Bool)` | Boolean | Məlumat dəyişdikdə animasiyalı keçidlərin aktivliyi. |
| `.onScroll((CGPoint) -> Void)` | Blok | Skrol offset qiymətlərini canlı izləmək üçün. |

---

## Tələblər (Requirements)

- iOS 13.0+ (iOS 16+ ilə əlavə performans optimizasiyası)
- Xcode 11+
- Swift 5.5+

---

## Müəllif və lisenziya

Bu layihə MIT lisenziyası altında yayılır. Layihənizdə sərbəst şəkildə istifadə edə, dəyişdirə bilərsiniz.
