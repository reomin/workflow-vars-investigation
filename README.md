# workflow-vars-investigation

GitHub Actions の `run:` ステップ内で `${{ ... }}` を直接使ったときに起きうる **OS コマンドインジェクション**（シェル解釈）の挙動を検証するためのリポジトリです。

## 問題: `run:` 内での `${{ ... }}` 直接展開

`run:` は最終的にシェル（多くの場合 `bash`）に渡されて実行されます。
その `run:` 文字列の中に `${{ github.event.pull_request.title }}` のような式を直接書くと、
式が展開された“結果の文字列”がシェルに渡り、シェルがそれを解釈します。

PR タイトルや `workflow_dispatch` 入力、Issue タイトルなど **外部由来で攻撃者が制御できる値**が混ざると、
`$(...)`（コマンド置換）や `;` などを使って意図しないコマンドを実行させられる可能性があります。

特に `pull_request_target` のように Secrets が利用できるイベントでは影響が大きくなります。

## このリポジトリでの検証方法

ワークフローは [.github/workflows/investigate_vars.yaml](.github/workflows/investigate_vars.yaml) にあります。

1. このリポジトリに対して PR を作成します（同一リポジトリ内のブランチでOK）
2. PR タイトルに、次のような文字列を入れます（例）

	 - `poc $(id >&2)`
	 - `poc $(uname -a >&2)`

3. PR を作る/更新すると Actions が走るのでログを確認します
