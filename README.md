# Gourmet-search-for-Fenrir

Hot Pepper Gourmet APIを利用したFlutterの店舗検索アプリです。

## セットアップ

### 必要な環境

- Flutter SDK（Dart SDKを含む）
- Android Studio
- Android SDK / Android Emulator、または位置情報を利用できるAndroid実機
- Hot Pepper Gourmet APIキー

Android向けのビルド設定は `compileSdk 36`、Java / Kotlinは17を使用します。

### 1. リポジトリを取得

```sh
git clone https://github.com/Yu-deeptale/Gourmet-search-for-Fenrir.git
cd Gourmet-search-for-Fenrir
```

### 2. 依存関係を取得

```sh
flutter pub get
```

### 3. APIキーを設定

プロジェクトルートにある `.env.example` を `.env` にコピーし、Hot Pepper
Gourmet APIキーを設定します。

```sh
copy .env.example .env
```

macOS / Linuxの場合は次のコマンドを使用します。

```sh
cp .env.example .env
```

`.env` の内容:

```dotenv
HOTPEPPER_API_KEY=YOUR_API_KEY
```

`.env` はAPIキーを含むため、Gitへコミットしないでください。
APIキーが未設定の場合、店舗検索時にエラーが表示されます。

### 4. Androidで起動

接続中の端末または起動済みエミュレーターを確認します。

```sh
flutter devices
```

アプリを起動します。

```sh
flutter run
```

リリース用APKを作成する場合:

```sh
flutter build apk --release
```

### 位置情報について

Androidでは [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) に
位置情報権限を設定済みです。実機で現在地検索を使用する場合は、端末の位置情報サービスを有効にし、
アプリの位置情報権限を許可してください。

現在地取得後に住所表示ができない環境でも、取得した緯度・経度を使った店舗検索は継続できます。

## 主な機能

- キーワード、検索範囲による店舗検索
- 現在地または都道府県・市区町村を指定した検索
- Wi-Fi、個室、飲み放題などの条件絞り込み
- 距離順、価格順での並び替え
- 店舗画像、住所、アクセス、営業時間、予算の表示
- 現在地から店舗までの距離表示
- ブックマークと店舗評価（Vote）
- `cached_network_image` による店舗画像表示
- 店舗詳細からGoogle Mapsを起動