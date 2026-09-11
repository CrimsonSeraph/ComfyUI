# custom/ — ComfyUI 本地特化目录（非上游）

本目录集中存放本机 ComfyUI 的**本地特化内容**，遵循 fork 友好原则：

- **不修改上游文件**：所有个性化内容都放在 `custom/` 下，ComfyUI 上游源码保持原样；
- **自带文档**：每个子目录都带 README，说明用途、用法与依赖；
- **可整体移除**：删除 `custom/` 不影响 ComfyUI 本体运行；
- **不与上游冲突**：ComfyUI 上游不存在 `custom/` 路径，`.gitignore` 也没有忽略它，
  因此拉取上游更新时既不会冲突，也不会被覆盖或删除（`git reset --hard` 不触碰未跟踪文件）。

## 子目录

| 路径 | 内容 |
| --- | --- |
| `launcher/` | 启动器：`start-comfyui.bat`（入口）、`_backend.cmd`（拉取更新 + 启动服务）、`run-app.ps1`（在专属 Edge 应用窗口打开）、`README.md` |
| `models/` | 模型清单：文件名、应放置的目录、下载地址 —— 见 [`models/README.md`](models/README.md) |
| `workflows/` | 特化工作流 JSON 与来源说明 —— 见 [`workflows/README.md`](workflows/README.md) |
| `shortcuts.md` | 桌面快捷方式（启动快捷键）的创建方法 + 常用界面快捷键 —— 见 [`shortcuts.md`](shortcuts.md) |

## 本机环境基线（2026-09 快照）

| 项目 | 值 |
| --- | --- |
| 仓库根目录 | 脚本自动推导，或用 `COMFY_APP_DIR` 指定（本仓库是 `CrimsonSeraph/ComfyUI` 的 fork，分支 `master`） |
| ComfyUI 的 Python | 由 `COMFY_PYTHON` 指定；未设置时自动探测仓库内 `.venv` / `venv` / `python_embeded`，最后用 PATH 上的 `python`（本机版本 3.13.9） |
| PyTorch | `2.10.0+cu128` |
| GPU | NVIDIA GeForce RTX 5070 Ti Laptop GPU（12 GB 显存，算力 sm_120） |
| Triton | `triton-windows 3.8.0.post28` |
| SageAttention | `sageattention 2.2.0+cu128torch2.10.0andhigher.post6` |
| 服务地址 | `http://127.0.0.1:8188` |
| 前端 | `comfyui-frontend-package`（PyPI 预编译包，**不需要 npm 编译**） |

> 下文安装命令统一写作 `python -m pip ...`。这里的 `python` **必须就是 ComfyUI 使用的那个解释器**：
> 本机没有虚拟环境，依赖装在全局 Python 中。若 `python` 指向别处（例如 Windows 上的 Microsoft Store
> 别名），请改用该解释器的完整路径。先核对是不是同一个：
>
> ```bat
> python -c "import sys;print(sys.executable)"
> ```
>
> 解释器探测顺序见 [`launcher/README.md`](launcher/README.md)，注意事项见 §1.7。

---

# 一、一次性环境部署（只需执行一次）

> 只有在**换机器、重装系统、更换 Python 版本、升级 PyTorch** 时才需要重做。
> 日常启动请直接看 [第二部分](#二每次启动都要执行)。
>
> ComfyUI 是纯 Python 项目，**没有传统意义上的"编译"步骤**：所谓"编译"就是下面第 1~4 步的依赖安装。

## 1.1 安装 PyTorch（必须最先装）

```bat
python -m pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu130
```

- README 建议 NVIDIA 20 系及以上使用 **cu130 或更高**。本机当前是 `2.10.0+cu128`，已实测可用（见下），
  所以没有强制升级；想要最新 CUDA 算子优化可按上面命令升级到 cu130。
- 验证 GPU 真的能用（不要只看安装成功）：

```bat
python -c "import torch;print(torch.__version__, torch.version.cuda, torch.cuda.is_available(), torch.cuda.get_device_name(0))"
```

本机实测结果：

```
2.10.0+cu128 12.8 True NVIDIA GeForce RTX 5070 Ti Laptop GPU
```

> **为什么必须最先装**：Triton 和 SageAttention 都是针对**特定 PyTorch 版本编译**的二进制包，
> 链接的是 torch 的 C++ ABI。先装 torch，再装它们，顺序反了会装出无法加载的组合。

## 1.2 安装 ComfyUI 依赖

```bat
cd /d <仓库根>
python -m pip install -r requirements.txt
```

这一步会一并安装前端（`comfyui-frontend-package`）、工作流模板（`comfyui-workflow-templates*`）、
`transformers`、`safetensors`、`alembic`、`av`、`kornia` 等。

> **前端不需要 npm 编译**。ComfyUI 的前端在 `Comfy-Org/ComfyUI_frontend` 独立仓库开发，
> 编译产物以 `comfyui-frontend-package` 的名字发布到 PyPI，`requirements.txt` 会把它装进来。
> 所以本机没有 Node.js/pnpm 依赖，也不需要 `npm run build`。

**ComfyUI-Manager 依赖（`--enable-manager` 必需）**

启动命令里带了 `--enable-manager`，它依赖 **ComfyUI-Manager** 这个独立扩展，需要单独装一次：

```bat
cd /d <仓库根>
python -m pip install -r manager_requirements.txt
```

本机已装：`comfyui_manager==4.2.2`。
**漏装这一项会导致加了 `--enable-manager` 后启动直接失败**（缺少 manager 模块）。

验证依赖完整性：

```bat
python -m pip check
```

期望输出：`No broken requirements found.`

## 1.3 安装 Triton（triton-windows）

**为什么需要**：ComfyUI 的 `xformers` 注意力后端（以及 SageAttention 的部分内核）依赖 Triton。
缺失时启动日志会出现：

```
ModuleNotFoundError: No module named 'triton'
A matching Triton is not available, some optimizations will not be enabled
```

**安装命令（两步，顺序不能颠倒）**：

```bat
rem 第一步：务必先卸载旧版（官方 triton 与 triton-windows 同名冲突）
python -m pip uninstall -y triton triton-windows

rem 第二步：安装 Windows 移植版
python -m pip install -U triton-windows
```

**注意事项（重要）**

1. **必须先删除旧版 triton**。官方 `triton` 包只支持 Linux，Windows 上要用 `triton-windows` 移植版，
   两者**安装名不同但导入名都是 `triton`**。若旧版残留，可能出现两种坏情况：
   装完后 `import triton` 仍指向被卸载一半的旧包，或直接 `ImportError: DLL load failed`。
   所以 `uninstall` 这一步**不能省**，两个包名都要写。
2. **必须装进 ComfyUI 用的那个 Python 环境**。先用 `python -c "import sys;print(sys.executable)"` 确认
   `python` 就是 ComfyUI 启动时用的那个解释器，再用 `python -m pip ...` 安装。直接敲 `pip install` 可能落到别的解释器
   （PATH 里还有 Microsoft Store 的 `python` 别名），结果是"装成功了但 ComfyUI 依然找不到 triton"。
3. **必须在 PyTorch 之后安装**（见 1.1）。Triton 的 wheel 与 torch 版本绑定，升级 torch 后要重装它。
4. **装完必须重启 ComfyUI**。Python 进程在启动时加载模块，运行中的服务不会自动获得新装的 triton。
5. **验证**：

```bat
python -c "import triton;print(triton.__version__)"
```

本机结果：`3.8.0.post28`

## 1.4 安装 SageAttention

从 <https://github.com/woct0rdho/SageAttention/releases> 下载与**本机 torch / CUDA / Python 精确匹配**的
wheel 文件，然后用 pip 安装该文件：

```bat
python -m pip install "下载目录\下载的文件名.whl"
```

**注意事项（重要）**

1. **版本必须三匹配**：文件名里的 `cp313`（Python 3.13）、`cu128`（必须与 torch 的 CUDA 版本一致）、
   `torch2.10`（必须与 torch 主版本一致）。三者任一不符，轻则安装后被忽略，重则运行时报错崩溃。
   本机使用的正是：`sageattention 2.2.0+cu128torch2.10.0andhigher.post6`。
2. **必须用下载的 wheel 安装，不要 `pip install sageattention`**。PyPI 上没有适配 Windows 的正式发行版，
   直接装会尝试源码编译（需要完整 CUDA 工具链）并大概率失败。
3. **必须先装好 PyTorch**。wheel 是编译产物，链接特定 torch 的 ABI。
4. **升级 torch 后必须重装**本 wheel，否则会因 ABI 不匹配而失效或崩溃。
5. **验证**：

```bat
python -c "import sageattention;print(sageattention.__version__)"
```

## 1.5 安装自定义节点

### MiniMax-H3 Turbo（git 克隆，会被启动器自动更新）

```bat
cd /d <仓库根>\custom_nodes
git clone --depth=1 https://github.com/larryvrh/ComfyUI-MiniMax-H3-Turbo
```

- 上游说明：<https://github.com/Larryvrh/ComfyUI-MiniMax-H3-Turbo>
- 作用：提供 **MiniMax-H3 Turbo LoRA** 与 **MiniMax-H3 Turbo Sampler** 两个节点，
  把官方 MiniMax-H3（视频 + 同步音频）工作流的采样步数从 ~20 步降到 **4~8 步**。
- 用法要点（详见上游 README）：在 `Load Diffusion Model → … → SamplerCustomAdvanced` 之间插入
  Turbo LoRA 节点并在 `BasicScheduler` 上选 `simple`、步数设 **4~8**；`strength` 保持 `1.0`。
- 该仓库**本地带一个 git 仓库**，因此启动器每次会浅拉取它的最新提交（见第二部分）。
  注意仓库根的 `.gitignore` 里有 `/custom_nodes/`，所以克隆进来的节点**不会被提交**，
  也不会被主仓库的 `git reset` 影响。

### 其他已装节点（非 git 克隆，启动器只跳过更新）

本机 `custom_nodes/` 下还有几个由 **ComfyUI-Manager 以压缩包方式**安装的节点，它们**没有 `.git` 目录**：

| 目录 | 更新方式 |
| --- | --- |
| `comfyui-impact-pack` | 用 ComfyUI-Manager 更新 |
| `comfyui-kjnodes` | 用 ComfyUI-Manager 更新 |
| `comfyui-videohelpersuite` | 用 ComfyUI-Manager 更新 |
| `rgthree-comfy` | 用 ComfyUI-Manager 更新 |

启动器只对**含 `.git` 的目录**做浅拉取，对这几个目录会自动跳过并提示，不会报错中断。

## 1.6 放置模型

模型文件名、应放的目录、下载地址见 [`models/README.md`](models/README.md)。
一键核对是否放齐：见该文件末尾的核对表。

## 1.7 一次性部署的注意事项汇总

| # | 事项 | 说明 |
| --- | --- | --- |
| 1 | **一律用 `python -m pip`** | 写成 `python -m pip ...`，不要用裸 `pip`。裸 `pip` 绑定的是它自己所在的那个解释器，多 Python 环境下极易装错地方。 |
| 2 | **不要混用解释器** | PATH 里存在 Microsoft Store 的 `python` 别名（执行会跳转应用商店）。ComfyUI 一律用与启动器相同的那个解释器，先用 `python -c "import sys;print(sys.executable)"` 核对。 |
| 3 | **装 Triton 前先删旧版** | `pip uninstall -y triton triton-windows` 后再装，两个包名都要卸。 |
| 4 | **版本三匹配** | SageAttention wheel 必须满足 `cp313` + `cu128` + `torch2.10`；Triton 也要与 torch 版本匹配。 |
| 5 | **安装顺序** | PyTorch → Triton / SageAttention → ComfyUI requirements → 模型。 |
| 6 | **升级 torch 后要重装** | Triton 与 SageAttention 都绑定 torch ABI，升级 torch 后必须重装这两者。 |
| 7 | **装完必须重启 ComfyUI** | 新装的 Python 模块只在进程启动时加载。 |
| 8 | **不要用 `pip install -r` 之外的方式改前端** | 前端升级走 `requirements.txt`，或用启动参数 `--front-end-version Comfy-Org/ComfyUI_frontend@latest`。 |
| 9 | **依赖安装失败不一定是致命的** | 启动日志中的 `cu130 or higher` 与 `Triton` 警告在 cu128 下仍可正常运行，只是拿不到部分算子优化。 |

---

# 二、每次启动都要执行

日常**只需双击** `custom\launcher\start-comfyui.bat`（或桌面快捷方式，见 [`shortcuts.md`](shortcuts.md)）。
它会自动完成下列全部步骤：

| 步骤 | 做什么 | 失败时的行为 |
| --- | --- | --- |
| 0 | 检测端口 `8188` 是否已在监听 | 已在运行 → **直接打开应用窗口**，不重复启动 |
| 1 | **浅拉取 ComfyUI 主仓库**：`git fetch --depth=1 origin master` → `git reset --hard FETCH_HEAD` | **只警告，不中断**，继续用本地版本启动 |
| 2 | **浅拉取 `custom_nodes/` 下所有 git 仓库**（含 MiniMax-H3-Turbo），每个都带 `--depth=1` | **只警告，不中断**；单个仓库失败不影响其他仓库，也不影响启动 |
| 3 | 主仓库**确实有更新时**才执行 `pip install -r requirements.txt` 同步依赖 | 只警告，不中断 |
| 4 | 启动服务：`python main.py --listen 127.0.0.1 --port 8188 --enable-manager --use-pytorch-cross-attention` | 前台运行，关窗口即停服 |
| 5 | 端口就绪后，在**专属 Edge 应用窗口**打开 `http://127.0.0.1:8188` | 找不到 Edge 则回退 Chrome `--app`，再回退系统默认浏览器 |

> **启动参数是本机实测必需的，不要省**：
>
> - `--enable-manager` —— 启用 ComfyUI-Manager（依赖 `comfyui_manager`，见 §1.2）；
> - `--use-pytorch-cross-attention` —— 强制走 PyTorch 原生 cross attention，
>   绕开 xformers / SageAttention 路径（本机用它是为了规避相关问题）。
>
> 启动器已把这两个参数**设为默认值**，双击即可得到正确命令；日志里会打印实际使用的命令行，
> 与 `http://127.0.0.1:8188/system_stats` 的 `argv` 字段可互相印证。

## 2.1 浅拉取（`--depth=1`）的三条安全规则

启动器把"拉取更新"做得尽量不破坏你的工作，逐仓库执行：

1. **工作区有未提交修改 → 跳过该仓库更新**。避免把正在改的东西冲掉。
2. **本地有未推送提交 → 跳过该仓库更新**（可通过 `COMFY_PULL_FORCE=1` 强制对齐远端）。
   判定方式：拉取前记录 `origin/<分支>` 的提交，与当前 `HEAD` 比较，不一致即说明有本地提交。
3. **任何失败都只打印 `[WARN]` 并继续**，绝不 `exit`。这保证"网络不通 / 没有权限 / 仓库损坏"时，
   ComfyUI 依然能用本地已有代码正常启动。

> **关于 `custom/` 与本地提交**：`custom/` 若一直保持**未跟踪**状态，那么无论拉取还是 `git reset --hard`
> 都不会动它，可以放心随上游更新。若你把 `custom/` 提交进本地仓库，请**同时推送到你的 fork**
> （`CrimsonSeraph/ComfyUI`），否则启动器会因为"存在未推送提交"而跳过更新。

## 2.2 手动执行的等价命令

不想用启动器时，等价的手工流程是：

```bat
cd /d <仓库根>

rem 1) 拉取主仓库（浅拉取；失败也不影响启动）
git fetch --depth=1 origin master && git reset --hard FETCH_HEAD

rem 2) 拉取自定义节点（逐个仓库，失败只警告）
cd custom_nodes\ComfyUI-MiniMax-H3-Turbo
git fetch --depth=1 origin main && git reset --hard FETCH_HEAD
cd ..\..

rem 3) 仅在主仓库有更新时同步依赖
python -m pip install -r requirements.txt

rem 4) 启动（--enable-manager 与 --use-pytorch-cross-attention 为本机实测必需，勿省）
python main.py --listen 127.0.0.1 --port 8188 --enable-manager --use-pytorch-cross-attention
```

## 2.3 启动器环境变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `COMFY_PORT` | `8188` | 服务端口（同时用于端口检测与 URL） |
| `COMFY_APP_DIR` | 由脚本位置推导 | 覆盖仓库根目录 |
| `COMFY_PYTHON` | 未设置时自动探测 | 覆盖 Python 解释器；探测顺序：`COMFY_PYTHON` → 仓库内 `.venv\Scripts\python.exe` → `venv\Scripts\python.exe` → `python_embeded\python.exe` → PATH 上的 `python` |
| `COMFY_NODES_DIR` | `<仓库根>\custom_nodes` | 覆盖自定义节点目录 |
| `COMFY_PULL_BRANCH` | `master` | 主仓库浅拉取的目标分支（自定义节点用各自当前分支） |
| `COMFY_NO_PULL` | - | 设为任意值：跳过所有 git 更新 |
| `COMFY_NO_INSTALL` | - | 设为任意值：即使有更新也不重装依赖 |
| `COMFY_PULL_FORCE` | - | 设为任意值：本地有未推送提交时仍强制对齐远端（**会丢弃本地提交**） |
| `COMFY_GC` | - | 设为任意值：拉取后执行 `git gc --prune=now` 压缩仓库（会让仓库保持浅克隆，较慢） |
| `COMFY_NO_BROWSER` | - | 设为任意值：不打开浏览器窗口（无头/CI） |
| `COMFY_NO_START` | - | 设为任意值：只做拉取/依赖同步，不启动服务 |
| `COMFY_DRY_RUN` | - | 设为任意值：只打印将要执行的步骤，不实际执行 |
| `COMFY_LISTEN` | `127.0.0.1` | 监听地址，设成 `0.0.0.0` 可让局域网访问 |
| `COMFY_ARGS` | `--enable-manager --use-pytorch-cross-attention` | **整体覆盖**附加到 `main.py` 的参数。本机实测必需的两个开关已是默认值；留空即用默认；设为 `-` 表示不带任何附加参数 |
| `COMFY_WINDOW_SIZE` | - | Edge 应用窗口尺寸，如 `1600,1000` |
| `COMFY_EDGE_PROFILE_DIR` | - | 使用独立的 Edge 用户数据目录（与日常浏览器配置隔离） |

示例——日常快速启动（不拉取、不检查依赖）：

```bat
set COMFY_NO_PULL=1 & set COMFY_NO_INSTALL=1
custom\launcher\start-comfyui.bat
```

示例——只做更新，不启动：

```bat
set COMFY_NO_START=1
custom\launcher\start-comfyui.bat
```

## 2.4 浅拉取的取舍与恢复

- `--depth=1` 只下载目标的**最新一次提交**，启动更快、占用更小；
- 代价是本地历史会被截断（仓库变为浅克隆）。想恢复完整历史：

```bat
cd /d <仓库根>
git fetch --unshallow
```

- 上游 ComfyUI 的更新日志与版本号可在界面或 `http://127.0.0.1:8188/system_stats` 查看。

---

# 三、故障排查

| 现象 | 原因与处理 |
| --- | --- |
| 双击 bat 一闪而过 | bat 本身有语法错误；用 `cmd /k` 打开，或设 `COMFY_DRY_RUN=1` 观察输出 |
| 提示"未找到仓库根目录" | `start-comfyui.bat` 必须放在 `<仓库>\custom\launcher\` 下；或设 `COMFY_APP_DIR` 指向仓库根 |
| `[WARN] … git fetch --depth=1 失败` | 网络/代理问题。不影响使用，继续用本地版本；修好网络后重跑启动器即可 |
| `[WARN] … 工作区有未提交修改，跳过更新` | 你有未提交的改动。提交或 `git stash` 后重跑 |
| `[WARN] … 本地有未被远端包含的提交` | 你本地有未推送提交。先 `git push`；确实要丢弃本地版本时用 `COMFY_PULL_FORCE=1` |
| 端口被占用 | 设 `COMFY_PORT=8189` 换个端口 |
| 启动后浏览器没自动打开 | 设了 `COMFY_NO_BROWSER`；或手动访问 `http://127.0.0.1:8188` |
| `[WARN] … git fetch --depth=1 failed` | 网络/代理问题。不影响使用，继续用本地版本；修好网络后重跑启动器即可 |
| `[WARN] … worktree has uncommitted changes` | 你有未提交的改动。提交或 `git stash` 后重跑 |
| `[WARN] … local commits are not pushed` | 你本地有未推送提交。先 `git push`；确实要丢弃本地版本时用 `COMFY_PULL_FORCE=1` |
| 启动器输出是英文 | 脚本刻意使用纯 ASCII 英文提示，原因见 [§3.1](#31-为什么启动器脚本用英文而不是中文)；消息的中文对照表见 [`launcher/README.md`](launcher/README.md) |
| 报错 `... was unexpected at this time.` | cmd 会把 `echo`/`rem` 文本里**未转义的半角括号**当成嵌套块。自行修改时请改用全角括号或 `^(` / `^)` 转义 |
| `custom\launcher\` 里冒出奇怪的空文件 | `echo`/`rem` 文本里出现了 `>` 或 `<`，被 cmd 当成重定向。文本中不要出现这些字符 |
| 同时开两个实例报 `Could not acquire lock on database` | 两个 ComfyUI 共用 `user\comfyui.db`。启动器默认检测端口、不会重复启动；确实要并行时给第二个实例加 `--database-url` 指向另一个库文件 |
| 日志仍有 `cu130 or higher` / `Triton` 警告 | cu128 下属正常提示，不影响运行，仅少部分算子优化；按 §1.1 / §1.3 升级可消除 |

## 3.1 为什么启动器脚本用英文而不是中文

`custom\launcher\` 下的脚本刻意写成**纯 ASCII + 英文提示**，这是实测踩坑后的结论：

1. **代码页不兼容**。批处理若存成 GBK，在代码页为 `65001`（UTF-8）的终端里会被按 UTF-8 解析，
   多字节中文字节会破坏行解析，cmd 把半行内容当命令执行，出现 `'fined' is not recognized` 之类
   难以定位的报错；存成 UTF-8 则在代码页 `936` 下同样出问题。**只有纯 ASCII 在任何代码页下都安全。**
2. **`>` 和 `<` 是重定向符**。cmd 对 `echo` 与 `rem` 的文本**照样解析重定向**，
   所以 `echo ... -> ...` 会被截断，后半段被当成文件名，在目录里生成奇怪的空文件。
   纯 ASCII 提示会刻意避开这些字符。
3. **中文说明没有丢**。所有解释与注意事项都在 `.md` 文档里（本文件与 [`launcher/README.md`](launcher/README.md)），
   脚本英文消息的中文对照表也在 `launcher/README.md` 中。

> 自行修改脚本时请沿用两条约定：**保持 ASCII**、**提示文本里不出现 `>` `<` `|` `&` `^` 与半角括号**。

---

# 四、与上游同步

- `custom/` 在 ComfyUI 上游不存在，合并上游更新时不会冲突；如需整体移除本地特化，删除 `custom/` 即可。
- 主仓库更新采用**浅拉取 + 快进对齐**，只对干净工作区生效；`custom/`（未跟踪）与其他未跟踪文件不受影响。
- 想给 ComfyUI 本体打补丁时，建议把补丁脚本放在 `custom/` 下并在本文件登记，而不是直接改上游文件。
