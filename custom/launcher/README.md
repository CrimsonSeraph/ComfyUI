# ComfyUI 启动器（custom/launcher）

本目录是**非上游本地扩展**（fork 友好原则）：所有文件都放在 `custom/` 下，
不改动 ComfyUI 任何上游文件，也不与上游更新冲突。

## 文件清单

| 文件 | 作用 |
| --- | --- |
| `start-comfyui.bat` | **入口**：环境检测、端口检测、决定"直接打开应用"还是"启动后端窗口" |
| `_backend.cmd` | 后端窗口内执行：浅拉取主仓库 → 浅拉取自定义节点 → 同步依赖 → 启动 ComfyUI，并唤起应用窗口 |
| `run-app.ps1` | 轮询等待端口就绪，然后用**专属 Edge/Chrome `--app` 窗口**打开 `http://127.0.0.1:<port>` |
| `.gitattributes` | 限定本目录 `.bat`/`.cmd` 工作区为 CRLF，保证 cmd.exe 可靠解析 |

## 使用方法

1. **直接双击** `start-comfyui.bat`；
2. 或建桌面快捷方式指向它（含"启动快捷键"设置方法）——见 [`../shortcuts.md`](../shortcuts.md)；
3. 或在命令行带环境变量调用，例如只更新不启动：

```bat
set COMFY_NO_START=1
custom\launcher\start-comfyui.bat
```

## 工作流程

```
start-comfyui.bat
  ├─ 检测端口 8188 是否已在监听
  │    ├─ 是 → 直接 run-app.ps1 打开应用窗口（不重复启动服务）
  │    └─ 否 → 在新控制台窗口（标题 "ComfyUI backend"）执行 _backend.cmd
  │
  └─ _backend.cmd
       ├─ [1/4] git fetch --depth=1 origin master + git reset --hard FETCH_HEAD   （主仓库）
       ├─ [2/4] 对 custom_nodes 下每个含 .git 的目录做同样的浅拉取                （自定义节点）
       ├─ [3/4] 仅当确有更新时：pip install -r requirements.txt                   （依赖同步）
       └─ [4/4] python main.py --listen 127.0.0.1 --port 8188 --enable-manager --use-pytorch-cross-attention
                 └─ 同时 start run-app.ps1 → 端口就绪后打开 Edge --app 窗口
```

> `--enable-manager` 与 `--use-pytorch-cross-attention` 是本机**实测必需**的两个开关，已写入
> `_backend.cmd` 作为默认值（变量 `ARGS`）。要改动请设 `COMFY_ARGS`（整体覆盖），设成 `-` 表示不带附加参数。

关闭后端控制台窗口即停止 ComfyUI 服务。

## 失败处理原则（重要）

**所有 git 拉取与依赖安装的失败都只打印 `[WARN]`，绝不中断启动。**
网络不通、没有权限、仓库损坏、远端分支不存在等情况，都不会阻止 ComfyUI 用本地已有代码启动。

具体保护规则（逐仓库独立判断）：

| 情况 | 行为 |
| --- | --- |
| 目录不含 `.git` | `[WARN]` 跳过该目录（如 Manager 以压缩包安装的节点） |
| 工作区有未提交修改 | `[WARN]` 跳过该仓库更新，保护你的改动 |
| 本地有未推送提交 | `[WARN]` 跳过该仓库更新；`COMFY_PULL_FORCE=1` 可强制对齐远端（**会丢弃本地提交**） |
| 游离 HEAD 状态 | `[WARN]` 跳过该仓库更新 |
| `git fetch` 失败 | `[WARN]` 继续用本地版本 |
| `git reset` 失败 | `[WARN]` 继续用本地版本 |
| `pip install` 失败 | `[WARN]` 继续启动服务 |

## 浅拉取说明

- 每个仓库都执行 `git fetch --depth=1 origin <分支>`，**只下载最新一次提交**，启动更快、占用更小；
- 主仓库的分支由 `COMFY_PULL_BRANCH` 指定（默认 `master`）；自定义节点仓库默认使用它**自己当前所在的分支**；
- 拉取后执行 `git reset --hard FETCH_HEAD` 对齐到远端（仅在"工作区干净且无未推送提交"时才会执行）；
- 代价：本地历史被截断为浅克隆。需要完整历史时执行 `git fetch --unshallow`；
- 默认**不**执行 `git gc --prune=now`（避免意外丢弃历史对象）；设 `COMFY_GC=1` 可开启压缩。

> `git reset --hard` 不会删除未跟踪文件，因此 `custom/` 与 `custom_nodes/` 下的内容都安全。

## 为什么用 Edge 应用窗口

ComfyUI 本身没有访问令牌（不同于带随机 token 的 `dsh web`），所以不需要捕获地址。
但 ComfyUI **启动较慢**（要加载模型、扫描节点），因此 `run-app.ps1` 会先轮询端口，
确认服务真的开始监听后再打开窗口，避免出现"浏览器先打开、页面报连接被拒绝"的体验。

窗口打开顺序：**Edge `--app` → Chrome `--app` → 系统默认浏览器**。
用 `--app` 打开时没有地址栏与标签页，看起来就像一个独立的 ComfyUI 桌面应用。

## 环境变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `COMFY_PORT` | `8188` | 服务端口（同时用于端口检测与 URL） |
| `COMFY_LISTEN` | `127.0.0.1` | 监听地址；设成 `0.0.0.0` 可让局域网访问 |
| `COMFY_APP_DIR` | 由脚本位置推导 | 覆盖仓库根目录 |
| `COMFY_PYTHON` | 未设置时自动探测 | 覆盖 Python 解释器；探测顺序：`COMFY_PYTHON` → 仓库内 `.venv\Scripts\python.exe` → `venv\Scripts\python.exe` → `python_embeded\python.exe` → PATH 上的 `python` |
| `COMFY_NODES_DIR` | `<仓库>\custom_nodes` | 覆盖自定义节点目录 |
| `COMFY_PULL_BRANCH` | `master` | 主仓库浅拉取的目标分支 |
| `COMFY_NO_PULL` | - | 跳过所有 git 更新 |
| `COMFY_NO_INSTALL` | - | 即使有更新也不重装依赖 |
| `COMFY_PULL_FORCE` | - | 本地有未推送提交时仍强制对齐远端 |
| `COMFY_GC` | - | 拉取后执行 `git gc --prune=now` 压缩仓库 |
| `COMFY_NO_BROWSER` | - | 不打开浏览器窗口（无头/CI） |
| `COMFY_NO_START` | - | 只做拉取/依赖同步，不启动服务 |
| `COMFY_DRY_RUN` | - | 只打印将要执行的步骤，不实际执行 |
| `COMFY_ARGS` | `--enable-manager --use-pytorch-cross-attention` | **整体覆盖**附加到 `main.py` 的参数；留空用默认，设为 `-` 表示不带附加参数（如 `set COMFY_ARGS=--preview-method auto`） |
| `COMFY_WINDOW_SIZE` | - | Edge 应用窗口尺寸，如 `1600,1000` |
| `COMFY_EDGE_PROFILE_DIR` | - | 独立的 Edge 用户数据目录（与日常浏览器配置隔离） |

## 解释器是怎么选出来的

`_backend.cmd` **不硬编码任何 Python 路径**（整个 `custom/` 目录都不含绝对路径），按顺序挑选：

1. 环境变量 `COMFY_PYTHON`；
2. 仓库内 `.venv\Scripts\python.exe`；
3. 仓库内 `venv\Scripts\python.exe`；
4. 仓库内 `python_embeded\python.exe`（Windows 便携版布局）；
5. PATH 上的 `python`，并用 `where python` 解析成完整路径。

启动横幅里的 `python :` 一行会打印**最终选中的解释器**，例如 `<绝对路径>\python.exe`。
装 Triton / SageAttention 之前，请先核对这一行指向的就是你打算安装依赖的那个环境
（即 `python -c "import sys;print(sys.executable)"` 的输出）。

## 脚本为什么是纯 ASCII 英文

三个脚本（`.bat` / `.cmd` / `.ps1`）刻意只用 ASCII 字符与英文提示，这是实测踩坑后的硬性约定：

1. **代码页不兼容**：`.bat`/`.cmd` 若存成 GBK，在代码页 `65001`（UTF-8）的终端里会被按 UTF-8 解析，
   中文字节破坏行解析，cmd 把半行当命令执行，报出 `'fined' is not recognized` 这类莫名其妙的错误；
   存成 UTF-8 则在代码页 `936` 下同样出问题。**纯 ASCII 在任何代码页下都能正确解析。**
2. **`>` `<` 是重定向符**：cmd 对 `echo` 和 `rem` 的文本**照样解析重定向**。
   `echo ... -> ...` 会把后半段当成文件名，在 `launcher\` 目录里生成奇怪的空文件。
   所以提示文本里刻意不出现 `>` `<` `|` `&` `^` 和半角括号。
3. `.ps1` 额外原因：Windows PowerShell 5.1 在没有 BOM 时按 ANSI 读取脚本，
   非 ASCII 内容会随代码页变化而乱码，因此同样只用 ASCII。

> **修改脚本时请沿用这两条约定**，否则会重现上述两类故障。
> 中文说明全部放在 `.md` 文档里，脚本消息的中文含义见下表。

### 脚本消息中文对照

| 脚本消息 | 含义 |
| --- | --- |
| `[OK] <repo>: up to date <branch>@<sha>` | 该仓库已是最新，无需更新 |
| `[OK] <repo>: updated to <branch>@<sha>` | 该仓库已成功快进到远端最新提交 |
| `[OK] node scan done: N git repo[s], M non-git dir[s] skipped.` | 自定义节点扫描完成：N 个 git 仓库，M 个非 git 目录（Manager 装的）被跳过 |
| `[WARN] <repo>: git fetch --depth=1 failed, keeping local version.` | 浅拉取失败（网络/代理），继续用本地版本，不中断 |
| `[WARN] <repo>: worktree has uncommitted changes, skipping.` | 工作区有未提交改动，跳过该仓库更新以保护你的修改 |
| `[WARN] <repo>: local commits are not pushed, skipping.` | 本地有未推送提交，跳过更新；可用 `COMFY_PULL_FORCE=1` 强制对齐（会丢弃本地提交） |
| `[WARN] <repo>: not a git repo, skipping.` | 该目录不是 git 仓库（Manager 压缩包安装），跳过 |
| `[WARN] <repo>: detached HEAD, skipping.` | 处于游离 HEAD 状态，跳过 |
| `[WARN] <repo>: no origin/<branch> ref, cannot judge local commits, skipping.` | 缺少远端跟踪分支记录，无法判断是否有本地提交，保守跳过 |
| `[SKIP] COMFY_NO_PULL is set, ...` | 已设 `COMFY_NO_PULL`，跳过 git 更新 |
| `[SKIP] COMFY_NO_INSTALL is set, ...` | 已设 `COMFY_NO_INSTALL`，跳过依赖同步 |
| `[SKIP] COMFY_NO_START is set, ...` | 已设 `COMFY_NO_START`，只做更新不启动服务 |
| `[SKIP] nothing changed, skipping dependency sync.` | 主仓库与节点都无更新，跳过 `pip install`（正常现象） |
| `[STEP 3] main repo changed, syncing deps ...` | 主仓库有更新，正在同步 `requirements.txt` |
| `[STEP 4] starting ComfyUI` | 正在启动服务，下一行是完整命令行 |
| `ComfyUI is already running at <url>, opening the app window.` | 端口已在监听，直接打开应用窗口，不重复启动 |
| `[launcher] ComfyUI is listening on <url>` | `run-app.ps1` 已确认端口就绪 |
| `[launcher] Opening app window: <edge path>` | 正在用 Edge 应用模式打开窗口 |
| `[ERROR] ComfyUI repo root not found` | 找不到仓库根目录，检查脚本位置或 `COMFY_APP_DIR` |
| `[ERROR] cannot run python` | 找不到可用的 Python，用 `COMFY_PYTHON` 指定 |

## 故障排查

- **报错 `... was unexpected at this time.`**：cmd 会把 `echo`/`rem` 文本里**未转义的半角括号**当成嵌套块。
  修改脚本时请用 `^(` / `^)` 转义，或干脆避开括号。
- **`launcher\` 目录里出现奇怪的空文件**：`echo`/`rem` 文本里写了 `>` 或 `<`，被 cmd 当成重定向。
- **双击后一闪而过**：脚本提前退出。用 `cmd /k start-comfyui.bat` 运行，或设 `COMFY_DRY_RUN=1` 观察输出。
- **每次都提示 `nothing changed`**：正常。启动器比对本地 `HEAD` 与远端提交，一致时打印 `up to date`。
- **想临时不拉取**：`set COMFY_NO_PULL=1` 后再启动。
- **启动服务后窗口立即关闭**：ComfyUI 自身启动失败（依赖缺失/端口占用/显存不足）。
  因为用了 `cmd /k`，后端窗口会停留在报错处，向上翻即可看到 Python traceback。
- **两个实例同时启动报 `Could not acquire lock on database`**：它们共用 `user\comfyui.db`。
  启动器默认检测端口、不会重复启动；确实要并行时给第二个实例加 `--database-url` 指向另一个库。
