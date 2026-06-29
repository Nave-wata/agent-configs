# agent-configs

複数の AI コーディングエージェント（Claude Code / Codex / opencode）の設定とスキルを **1 つのリポジトリに統合**し、`agent-setup` スクリプト 1 つで各プロジェクトへ展開・更新できるようにしたもの。

プロジェクトごとに複数の設定リポジトリをクローンする手間をなくすことが目的。クローンはこのリポジトリ 1 回だけで済む。

## 構成

```
agent-configs/
├── bin/agent-setup        # 展開スクリプト（これ1本で配布・更新）
├── claude/   → 展開先 <project>/.claude/      # Claude Code 設定・スキル
├── codex/    → 展開先 <project>/.codex/       # Codex 設定・スキル・hooks
├── opencode/ → 展開先 <project>/.opencode/    # opencode 設定・スキル
└── README.md
```

各トップレベルディレクトリ `X/` が、対象プロジェクトの `.X/` に対応する。

## 使い方

### 初回セットアップ（任意：PATH を通す）

```sh
# どのプロジェクトからでも `agent-setup` と打てるようにする例
ln -s ~/Tools/agent-configs/bin/agent-setup /usr/local/bin/agent-setup
# もしくは alias agent-setup="~/Tools/agent-configs/bin/agent-setup"
```

スクリプトは**自身の位置からリポルートを解決する**ため、このリポジトリをどこに置いても動作する。

### 展開・更新

```sh
cd ~/work/my-project
agent-setup            # カレントディレクトリに展開
# または
agent-setup ~/work/my-project   # パス指定でも可
```

実行すると `<project>/.claude/`・`.codex/`・`.opencode/` が作成・更新される。**設定を更新したいときは、このリポジトリを編集して各プロジェクトで再実行するだけ**。

## 展開方式：コピー（シンボリックリンクではない）

設定ファイルの**実体を各プロジェクトにコピー**する。これは sandbox 実行（`sbx` = Docker Sandboxes）でエージェントを起動する場合、コンテナにマウントされるのは**そのプロジェクトディレクトリだけ**であり、リポジトリ外を指すシンボリックリンクはコンテナ内でリンク切れになるため。実体をプロジェクト内に置くことで、sandbox 内でも確実に読み込まれる。

トレードオフとして「中央を 1 回編集すれば全プロジェクトに即反映」はできない。更新時は各プロジェクトで `agent-setup` を再実行する。

## 更新時の挙動：マニフェスト方式

展開したファイル一覧を各プロジェクトの `.agent-configs-manifest` に記録する。再実行時は:

- このリポジトリに**今あるファイル** → コピー（追加・上書き）
- 前回配ったが**このリポジトリから消えたファイル** → 削除
- マニフェストに**無いファイル**（＝プロジェクト固有のファイル） → **一切触らない**

これにより「中央で削除した設定はちゃんと反映」しつつ「プロジェクト固有の `.claude` 配下ファイルは保護」を両立する。

### 設定ファイルの配布

- `settings.json` … プロジェクトごとに管理される（プロジェクトの git に入る）ため**配布しない**。各プロジェクトの既存 `settings.json` はマニフェスト管理外なので触らない（保護）
- `settings.local.json` … 個人共通のローカル設定として**配布する**
- `.gitignore` … 配布しない（旧・独立リポ時代の名残）

## 各ツールの内容

### Claude Code（`claude/`）

- `CLAUDE.md` … 共通方針（日本語応答、gh CLI ポリシー、TLS フォールバック等）。Codex / opencode もこれを参照する
- `skills/` … `commit`・`commit-pr`・`release`・`review`・`review-fix-loop`・`review-iterate`
- `statuslines/` … ステータスライン用スクリプト

### Codex（`codex/`）

- `config.toml`・`instructions.md`・`rules/`・`hooks/`
- `skills/` … `commit`・`commit-pr`・`review`・`release`（Codex 適応版。`$commit` のように起動）

### opencode（`opencode/`）

- `opencode.json` … `instructions` で `.claude/CLAUDE.md` を参照し、共通方針を共有
- `skills/review/` … opencode 単体で動くレビュー
- commit 系スキルは opencode が `.claude/skills/` を**互換スキルとして直接読み込む**ため、opencode 用に重複コピーしていない

## スキルの移植範囲

| スキル | claude | codex | opencode |
|--------|:------:|:-----:|:--------:|
| commit | ✓ | ✓ | ✓（`.claude/skills` 互換読み） |
| commit-pr | ✓ | ✓ | ✓（同上） |
| release | ✓ | ✓ | ✓（同上） |
| review | ✓ | ✓ | ✓（opencode 専用簡略版） |
| review-fix-loop | ✓ | — | — |
| review-iterate | ✓ | — | — |

`review-fix-loop` / `review-iterate` は Claude Code 固有のサブエージェント・MCP オーケストレーションに依存するため、**Claude Code 専用**。

スキル内のリポジトリ参照はハードコードせず、実行時に `gh` / `git remote` から動的取得するため、どのリポジトリでも動作する。

## opencode でローカル ollama を使う（sbx microVM 前提）

`opencode/opencode.json` には、ローカルの ollama に接続する provider 設定を入れてある:

- モデル: `ollama/opencode:latest`（provider `ollama` ＋ モデル `opencode:latest`）
- `baseURL`: `http://host.docker.internal:11434/v1`

**opencode を sbx（Docker Sandboxes / microVM）で動かす前提**のため、sandbox 内から「ホスト側の ollama」へ越境する。ここで **2つのアドレスは別物**なので分けて考える:

- **`baseURL`（sandbox 側＝opencode.json）** … sandbox からホストを見つけるアドレス。`host.docker.internal`（`localhost` は sandbox 自身を指すので不可）。**セキュリティとは無関係**で変更不要。
- **`OLLAMA_HOST`（ホスト側＝ollama の待受インターフェース）** … LAN への露出を決める**唯一のセキュリティ設定**。

### 1. ollama の待受（LAN に露出させない）

LAN 上の他マシンから ollama に届かないよう、待受インターフェースを絞る。セキュアな順に:

1. **デフォルトの `127.0.0.1`（ローカル限定）のまま試す**（推奨）。Docker Desktop for Mac では sandbox から `host.docker.internal` 経由でホストの `127.0.0.1` に届くことが多く、これなら **LAN 露出はゼロ**。
   - sandbox 内で到達確認: `curl -s http://host.docker.internal:11434/api/tags`
   - **応答する → これで完了**（最も安全）
2. **届かない場合のみ**、`0.0.0.0`（全 NIC）ではなく **sandbox が来るブリッジ IP だけ**に bind する。sandbox 内で `ip route | grep default` のゲートウェイを調べ、ホスト側の対応ブリッジ IP で `OLLAMA_HOST=<bridge-ip>:11434 ollama serve`。物理 NIC を除外するので LAN からは到達できない。
3. **最終手段**: `0.0.0.0`（LAN 全体に露出）＋ ホストのファイアウォール（macOS pf 等）で `:11434` を Docker サブネットに限定。最も非推奨。

### 2. sbx の outbound 許可

sandbox からホスト宛の通信を許可する。**これは sandbox の outbound 制御であって、ホストポートの LAN 隔離とは無関係**（LAN 隔離は上記 1 の待受アドレスだけで決まる）:

```sh
sbx policy allow network -g host.docker.internal:11434
```

### 3. host.docker.internal が解決しない場合

`host.docker.internal` は Docker 標準名だが、sbx microVM で解決できない場合は sandbox 内 `ip route | grep default` のゲートウェイ IP を `opencode.json` の `baseURL` に設定し、`agent-setup` で再展開する。

> sandbox を介さず直接 opencode を動かす場合、`baseURL` は `host.docker.internal` ではなく `localhost`（`http://localhost:11434/v1`）に変える。
