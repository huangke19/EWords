# Inkwell

Inkwell 是一个给中文母语者使用的英语单词记忆应用：收词、生成解释、按 SRS 复习，再用英文解释反向检验是否真的理解。

技术栈很直接：Go 标准库 HTTP + SQLite + HTMX，无前端构建步骤，默认运行在 `9090` 端口。

## 核心功能

- 添加单词并保存上下文、页面标题、来源 URL
- 调用 Groq 生成音标、英中文释义、例句、使用场景和记忆提示
- 词形归一化，优先解释原形词条
- 本地词表 + CEFR 评级，给出频率和推荐等级
- SRS 复习：记得 / 不记得 + 英文解释验收
- 浏览器扩展支持划词收词和右键收词

## 项目结构

```text
.
├── main.go
├── config/
├── db/
├── handlers/
├── models/
├── srs/
├── freq/
├── templates/
├── static/
├── extension/
├── start.sh
├── stop.sh
└── deploy-vps.sh
```

## 运行要求

- Go 1.26.1 或更高
- 可用的 `GROQ_API_KEY`

## 快速开始

```bash
git clone https://github.com/huangke19/Inkwell.git
cd Inkwell
cp .env.example .env
```

编辑 `.env`：

```bash
GROQ_API_KEY=your_groq_api_key_here
DB_PATH=ewords.db
```

启动：

```bash
./start.sh
```

访问 [http://localhost:9090](http://localhost:9090)

停止：

```bash
./stop.sh
```

如果不用脚本，也可以直接运行：

```bash
export GROQ_API_KEY=your_groq_api_key_here
go run main.go
```

## 开发说明

- 数据库默认是 `ewords.db`
- 服务端口当前固定为 `9090`
- 启动时会自动执行 SQLite migration
- 前端以服务端模板 + HTMX 为主，样式集中在 `static/style.css`

## 浏览器扩展

扩展目录在 `extension/`，默认连接本地 `http://localhost:9090`。

如果你把 Inkwell 部署到别的地址，需要同步修改：

- `extension/content.js`
- `extension/popup.js`
- `extension/manifest.json`

## 部署

仓库内置 VPS 部署脚本：

```bash
./deploy-vps.sh
```

如果要把本地数据库一并同步到服务器：

```bash
./deploy-vps.sh --with-db
```

可通过这些环境变量覆盖默认部署目标：

- `INKWELL_REMOTE_HOST`
- `INKWELL_REMOTE_DIR`
- `INKWELL_REMOTE_SERVICE`
- `INKWELL_REMOTE_URL`

## 当前限制

- 没有用户系统，默认单机使用
- 没有鉴权，不适合直接暴露到公网
- 扩展默认只连接本机地址
- SRS 规则目前是简单倍增模型

