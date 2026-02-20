# workflow-vars-investigation

GitHub Actions の `run:` ステップ内で `${{ ... }}` を直接使ったときに起きうる **OS コマンドインジェクション**（シェル解釈）の挙動を検証するためのリポジトリです。

## 問題: `run:` 内での `${{ ... }}` 直接展開

`run:` は最終的にシェル（多くの場合 `bash`）に渡されて実行されます。
その `run:` 文字列の中に `${{ github.event.pull_request.title }}` のような式を直接書くと、
式が展開された“結果の文字列”がシェルに渡り、シェルがそれを解釈します。

PR タイトルや `workflow_dispatch` 入力、Issue タイトルなど **外部由来で攻撃者が制御できる値**が混ざると、
`$(...)`（コマンド置換）や `;` などを使って意図しないコマンドを実行させられる可能性があります。

特に `pull_request_target` のように Secrets が利用できるイベントでは影響が大きくなります。

## このリポジトリでの検証手順

ワークフローは [.github/workflows/investigate_vars.yaml](.github/workflows/investigate_vars.yaml) にあります。

1. このリポジトリに対して PR を作成します（同一リポジトリ内のブランチでOK）
2. PR タイトルに、次のような文字列を入れます（例）

	 - `poc $(echo INJECTED >&2)`
	 - `poc echo INJECTED >&2`

3. PR を作る/更新すると Actions が走るのでログを確認します

## なぜ危険なのか（ダブルクオートあり/なし両方）

### 1) ダブルクオートありでも危険なケース（例: `"${{ ... }}"`）

`run:` の本文に `${{ ... }}` を直接埋め込むと、展開後の結果が「そのままシェルスクリプトの本文」になります。
その結果、外部入力にコマンド置換 `$(...)`（または `` `...` ``）が含まれていると、**ダブルクオートの中でも bash がコマンド置換を実行**してしまいます。

例（PR タイトルが `poc $(echo INJECTED >&2)` のとき）:

- `run: echo "${{ github.event.pull_request.title }}"`
- 実際に bash に渡る: `echo "poc $(echo INJECTED >&2)"`

このとき `echo INJECTED >&2` が実行され、ログに `INJECTED` が出ます。

### 2) ダブルクオートなしはさらに危険なケースが増える（例: `${{ ... }}` / `$VAR` 未クオート）

ダブルクオートがない場合、コマンド置換に加えて次が起きます。

- **シェルの制御演算子**（`;` `&` `|` `||` `&&` 改行）が混ざると、コマンドが分割されて実行され得る
- **単語分割**（スペース/改行で引数が増える）
- **グロブ展開**（`*` `?` がファイル名に展開される）

例（危険）:

- `run: echo ${{ github.event.pull_request.title }}`
- `run: ./script.sh ${{ github.event.pull_request.title }}`
- `run: ./script.sh $TITLE`（`$TITLE` が未クオート）

## 対策（推奨パターン）

外部由来の値は `env:` に入れて「データ」として渡し、`run:` 側では必ず `"$VAR"` のようにクオートして参照します。

```yaml
- name: Safe
	shell: bash
	env:
		TITLE: ${{ github.event.pull_request.title }}
	run: |
		printf '%s\n' "$TITLE"
```

※ただし `env` 経由でも、`eval "$TITLE"` や `bash -c "$TITLE"` のように「値を再解釈して実行」すると危険です。
