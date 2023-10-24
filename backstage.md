# Backstage

## はじめる

ほとんどの Backstage インストールでは、スタンドアロン アプリをインストールすると、最高かつ最も合理化されたエクスペリエンスが得られます。このガイドでは次のことを行います。

npm パッケージを使用して Backstage Standalone をデプロイする
SQLite インメモリ データベースとデモ コンテンツを使用して Backstage Standalone を実行する
このガイドは、apt-get、npm、yarn、curl などのツールを使用した Linux ベースのオペレーティング システムでの作業の基本を理解していることを前提としています。 Docker の知識は、Backstage インストールを最大限に活用するのにも役立ちます。

プラグインやプロジェクト全般に貢献する予定がある場合は、コントリビューター ガイドを使用してリポジトリ ベースのインストールを行うことをお勧めします。

## 前提条件

- Linux、MacOS、Linux 用 Windows サブシステムなどの Unix ベースのオペレーティング システムへのアクセス
- コマンドラインで利用できる GNU のようなビルド環境。たとえば、Debian/Ubuntu では、make および build-essential パッケージをインストールする必要があります。 MacOS では、xcode-select --install を実行して、XCode コマンド ライン ビルド ツールを配置する必要があります。
- 依存関係をインストールするための昇格された権限を持つアカウント
- curl または wget がインストールされている
- Node.js アクティブ LTS リリースは、次のいずれかの方法を使用してインストールされます。
  - nvm の使用 (推奨)
    - nvmのインストール
    - nvm を使用してノードのバージョンをインストールおよび変更する
  - バイナリのダウンロード
  - パッケージマネージャー
  - NodeSource パッケージの使用
- yarn のインストール
  - 新しいプロジェクトを作成するには Yarn クラシックを使用する必要がありますが、その後 Yarn 3 に移行できます。
- docker のインストール
- gitのインストール
- ネットワーク経由でシステムに直接アクセスできない場合は、ポート 3000、7007 を開く必要があります。これは、コンテナー、VM、またはリモート システムにインストールする場合を除き、非常にまれです。

## ローカル

```bash
anyenv update
nodenv install --list
nodenv install 18.15.0
nodenv global 18.15.0
nodenv rehash
npm install -g yarn
nodenv rehash
```

### Backstage アプリを作成する

Backstage Standalone アプリをインストールするには、Node 実行可能ファイルをレジストリから直接実行するツールである npx を利用します。このツールは、Node.js インストールの一部です。以下のコマンドを実行すると、Backstage がインストールされます。ウィザードは、現在の作業ディレクトリ内にサブディレクトリを作成します。

```bash
npx @backstage/create-app@latest
```

> 注: `yarn install` のインストール手順でこれが失敗した場合は、`isolation-vm` の構成に使用される追加の依存関係をインストールする必要がある可能性があります。要件セクションで詳細を確認し、これらの手順を完了した後、yarn install を手動で再度実行できます。

ウィザードはアプリの名前を尋ねます。これはディレクトリの名前にもなります。

### Backstage アプリを実行する

インストールが完了したら、アプリケーション ディレクトリに移動してアプリを起動できます。 yarn dev コマンドは、フロントエンドとバックエンドの両方を同じウィンドウ内で別個のプロセス ([0] および [1] という名前) として実行します。

```bash
cd backstage
yarn install
yarn dev
```

https://github.com/backstage/backstage/issues/16071

## Backstage の Docker イメージの構築

このセクションでは、Backstage アプリをデプロイ可能な Docker イメージに構築する方法について説明します。このセクションは 3 つのセクションに分かれており、最初にホスト ビルド アプローチについて説明します。ホスト ビルド アプローチは、その速度とより効率的で、多くの場合より単純なキャッシュのため推奨されます。 2 番目のセクションでは完全なマルチステージ Docker ビルドについて説明し、最後のセクションではフロントエンドとバックエンドを個別のイメージとしてデプロイする方法について説明します。

これらの Docker デプロイメント戦略すべてに言えることは、ステートレスであるため、実稼働デプロイメントの場合は、SQLite を使用するのではなく、バックエンド プラグインが状態を保存できる外部 PostgreSQL インスタンスをセットアップして接続することをお勧めします。

このセクションでは、アプリが `@backstage/create-app` ですでに作成されており、フロントエンドがバンドルされ、バックエンドから提供されることを前提としています。これは `@backstage/plugin-app-backend` プラグインを使用して行われ、フロントエンド構成もアプリに挿入されます。つまり、Backstage の最小限のセットアップで 1 つのコンテナーを構築してデプロイするだけで済みます。フロントエンドの提供をバックエンドから分離したい場合は、以下の別個のフロントエンドのトピックを参照してください。

## ホストビルド

このセクションでは、Backstage リポジトリから Docker イメージをビルドする方法について説明します。ビルドのほとんどは Docker の外部で行われます。ビルド ステップがより高速に実行される傾向があり、ホスト上で依存関係をより効率的にキャッシュできるため、ほとんどの場合、これがより高速なアプローチです。1 つの変更でキャッシュ全体が破壊されることはありません。

ホスト ビルドで必要な手順は、`yarn install` で依存関係をインストールし、`yarn tsc` で型定義を生成し、`yarn build:backend` でバックエンド パッケージをビルドすることです。

CI ワークフローでは、ルートから次のようになります。

```bash
yarn install --frozen-lockfile

# tsc outputs type definitions to dist-types/ in the repo root, which are then consumed by the build
yarn tsc

# Build the backend, which bundles it all up into the packages/backend/dist folder.
# The configuration files here should match the one you use inside the Dockerfile below.
yarn build:backend --config ../../app-config.yaml
```

ホストのビルドが完了したら、イメージをビルドする準備が整います。`@backstage/create-app` で新しいアプリを作成する場合、次の `Dockerfile` が含まれます。

```dockerfile
FROM node:18-bookworm-slim

# Install isolate-vm dependencies, these are needed by the @backstage/plugin-scaffolder-backend.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends python3 g++ build-essential && \
    yarn config set python /usr/bin/python3

# Install sqlite3 dependencies. You can skip this if you don't use sqlite3 in the image,
# in which case you should also move better-sqlite3 to "devDependencies" in package.json.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends libsqlite3-dev

# From here on we use the least-privileged `node` user to run the backend.
USER node

# This should create the app dir as `node`.
# If it is instead created as `root` then the `tar` command below will fail: `can't create directory 'packages/': Permission denied`.
# If this occurs, then ensure BuildKit is enabled (`DOCKER_BUILDKIT=1`) so the app dir is correctly created as `node`.
WORKDIR /app

# This switches many Node.js dependencies to production mode.
ENV NODE_ENV production

# Copy repo skeleton first, to avoid unnecessary docker cache invalidation.
# The skeleton contains the package.json of each package in the monorepo,
# and along with yarn.lock and the root package.json, that's enough to run yarn install.
COPY --chown=node:node yarn.lock package.json packages/backend/dist/skeleton.tar.gz ./
RUN tar xzf skeleton.tar.gz && rm skeleton.tar.gz

RUN --mount=type=cache,target=/home/node/.cache/yarn,sharing=locked,uid=1000,gid=1000 \
    yarn install --frozen-lockfile --production --network-timeout 300000

# Then copy the rest of the backend bundle, along with any other files we might want.
COPY --chown=node:node packages/backend/dist/bundle.tar.gz app-config*.yaml ./
RUN tar xzf bundle.tar.gz && rm bundle.tar.gz

CMD ["node", "packages/backend", "--config", "app-config.yaml"]
```

`backend:bundle` コマンドと `skeleton.tar.gz` ファイルの動作の詳細については、backend:bundle コマンドのドキュメントを参照してください。

`Dockerfile` は `packages/backend/Dockerfile` にありますが、ルートの `yarn.lock` と `package.json`、およびその他のファイルにアクセスするには、リポジトリのルートをビルドコンテキストとして実行する必要があります。`.npmrc` などのファイルが必要です。

`@backstage/create-app` コマンドは、リポジトリのルートに次の `.dockerignore` を追加し、ビルド コンテキスト サイズを削減してビルドを高速化します。

```text
.git
.yarn/cache
.yarn/install-state.gz
node_modules
packages/*/src
packages/*/node_modules
plugins
*.local.yaml
```

プロジェクトがビルドされ、`.dockerignore` と `Dockerfile` が配置されたので、最終イメージをビルドする準備が整いました。リポジトリのルートからビルドを実行します。

```bash
docker image build . -f packages/backend/Dockerfile --tag backstage
```

イメージをローカルで試すには、次のコマンドを実行できます。

```bash
docker run -it -p 7007:7007 backstage
```

その後、ターミナルでログの取得を開始し、[http://localhost:7007](http://localhost:7007) でブラウザを開くことができます。
