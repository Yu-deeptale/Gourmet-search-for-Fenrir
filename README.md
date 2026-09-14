# Gourmet-search-for-Fenrir

Hot Pepper Gourmet APIを利用したFlutterの店舗検索アプリです。

## セットアップ

Flutter SDKをインストール後、依存関係を取得します。

```sh
flutter pub get
```

APIキーはソースコードに直書きせず、プロジェクトルートの `.env` に設定してください。
`.env.example` を `.env` にコピーしてから、APIキーを入力します。

```dotenv
HOTPEPPER_API_KEY=YOUR_API_KEY
```

`HOTPEPPER_API_KEY` が未設定の場合、検索時に設定方法を表示します。

## 主な機能

- キーワード、検索範囲による店舗検索
- `permission_handler`、`geolocator`、`geocoding` による現在地検索と都道府県・市町村表示
- `cached_network_image` による店舗画像表示
- 店舗詳細からGoogle Mapsを起動

Androidでは [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) に位置情報権限を設定済みです。実機で確認する場合は、端末の位置情報サービスも有効にしてください。