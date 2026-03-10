# プロトタイプ実装計画書：Chaos Gear (仮)

## 1. プロジェクト概要・ゴール

* **目的:** 「10秒ごとの操作反転」と「カスタム物理演算によるキビキビとした2Dアクション」のコアシステムを検証する動的プロトタイプ。
* **スコープ:** キャラクターの移動・ジャンプ、当たり判定（簡易Box）、10秒ごとの入力マッピング反転ギミック（難易度による2パターンのアルゴリズム）。
* **除外スコープ:** 敵キャラクター、攻撃処理の実装、Tiledマップ、グリッチ・ボーナス（0.5秒の猶予判定）。

## 2. 開発環境・必須パッケージ

* **Flutter SDK:** 3.19以上推奨 (Dart 3.3以上)
* **依存パッケージ (pubspec.yaml):**
  * `flame`: ^1.16.0 (コアゲームエンジン)
  * `flame_gamepad`: ^1.0.0 (コントローラー対応用)
  * `flutter_riverpod`: ^2.4.9 (状態管理・タイマー・難易度管理用)

## 3. ディレクトリ構成（クリーンアーキテクチャ風）

Flameのゲームロジックと、Flutter/RiverpodのUI・状態管理を明確に分離する。

```text
lib/
 ┣ main.dart                # RiverpodのProviderScopeとアプリのエントリポイント
 ┣ application/             # 状態管理 (Riverpod)
 ┃ ┣ providers/             # 難易度設定、タイマー、現在の操作マッピング状態のProvider群
 ┃ ┗ models/                # LogicalAction (enum) などのデータモデル
 ┣ presentation/            # FlutterのUI (Flameのレイヤーの上に乗るUI)
 ┃ ┣ screens/               # タイトル画面（難易度選択）、ゲーム画面
 ┃ ┗ widgets/               # ホログラムリングUI、デバッグ用マッピング表示UI
 ┗ game/                    # Flameのゲーム内部ロジック
   ┣ chaos_gear_game.dart   # FlameGameを継承したメインクラス
   ┣ components/            # ゲーム内オブジェクト
   ┃ ┣ player_component.dart# プレイヤー（描画、物理演算、移動・ジャンプ処理）
   ┃ ┗ level_mockup.dart    # 簡易的な床・壁 (RectangleComponent)
   ┣ core/                  # ゲーム内コアシステム
   ┃ ┣ input_manager.dart   # 物理キー/ボタン入力を監視し、論理アクションに変換するクラス
   ┃ ┗ physics_config.dart  # 重力値、ジャンプ力、最高速度などの定数群
   ┗ assets/                # アセットパスの定数管理
```

## 4. コアシステムの設計詳細

**4.1 状態管理 (Riverpod) と Flame の連携**

* `DifficultyProvider`: 操作反転のアルゴリズム（A: ランダムシャッフル / C: ローテーション）を保持。
* `InputMappingProvider`: 10秒ごとに更新される「物理入力 → 論理アクション（LogicalAction）」の変換テーブルを保持。
* **連携フロー**: Riverpodのタイマーが10秒ごとに発火 -> `InputMappingProvider`を更新 -> `ChaosGearGame` (Flame) に変更を通知 -> Flame内の `InputManager` が新しいマッピングを参照してプレイヤーを動かす。

**4.2 入力仕様 (Input Mapping)**
初期状態（正常時）の割り当ては以下の通り。10秒ごとにこの割り当て先（LogicalAction）が入れ替わる。

* キーボード:
  * 移動: `W, A, S, D` または `Arrow Keys`
  * ジャンプ: `Space`
  * ダッシュ: `Q` (※プロトタイプではログ出力のみ)
  * 通常攻撃: `Z` (※同上)
  * 必殺攻撃: `X` (※同上)
* ゲームパッド (Switch準拠):
  * 移動: `D-Pad` または `Left Stick`
  * ジャンプ: `B` (下ボタン)
  * ダッシュ: `ZL` または `ZR`
  * 通常攻撃: `Y` (左ボタン) または `R`
  * 必殺攻撃: `X` (上ボタン) または `L`

**4.3 物理演算 (カスタム・キネマティクス)**
Box2Dは使用せず、`PlayerComponent` の `update` メソッド内で以下のカスタム計算を行う。

1. **重力**: 毎フレーム `velocity.y += gravity * dt` を適用。落下速度の最大値（Terminal Velocity）を設ける。
2. **移動**: `velocity.x` に対して、入力方向への加速と、入力がない時の摩擦（減速）を適用。キビキビ動くように摩擦は高めに設定。
3. **ジャンプ**: 接地フラグが `true` の時のみ `velocity.y = -jumpForce` を適用。
4. **当たり判定**: Flame標準の `RectangleHitbox` と `CollisionCallbacks` を使用。床と衝突したら `velocity.y = 0` とし、接地フラグを `true` にする。

**5. 開発のステップ（マイルストーン）**

1. Step 1: 基礎セットアップ: パッケージの導入と、単色の四角形（Player）が重力で落ちて床（LevelMockup）に乗る処理を作る。
2. Step 2: 正常な入力処理: Riverpodと連携し、キーボード/ゲームパッドの入力で正常に移動・ジャンプできるようにする。
3. Step 3: 10秒反転ギミックの実装: Riverpod側で10秒タイマーを回し、「ローテーション」または「完全ランダム」で入力を書き換える処理を実装。画面上部にデバッグテキストとして「現在の操作：Space=ジャンプ」などを表示させる。
