# models/ — 模型清单与下载地址（本机特化）

本文件登记本机用到的模型：**文件名、应放置的目录、下载地址**。
ComfyUI 的模型目录结构固定，**文件名必须与工作流里引用的完全一致**，否则节点会报找不到模型。

> 本目录只放**说明文档**。模型权重体积很大（几十 GB），**不要**把它们提交进仓库，
> 请放在仓库的 `models\` 下对应的子目录里（仓库根的 `.gitignore` 已忽略模型文件）。

## 1. MiniMax-H3（视频 + 同步音频）

配套自定义节点：[`custom_nodes/ComfyUI-MiniMax-H3-Turbo`](../custom_nodes/ComfyUI-MiniMax-H3-Turbo)（启动器自动更新），
上游说明：<https://github.com/Larryvrh/ComfyUI-MiniMax-H3-Turbo>

### 1.1 Turbo LoRA（本节点的核心）

来源：<https://huggingface.co/larryvrh/MiniMax-H3-Turbo-Lora>
放置目录：`models\loras\`

| 文件名 | 说明 |
| --- | --- |
| `minimax_h3_turbo_v4_step600_ema.safetensors` | **推荐**。上游 README 认为这是目前最强的一版：静态/小幅运动镜头明显更好，微细节（人脸、手指、材质）更强，且修掉了 v1 的过锐/塑料感。代价：**4 步 + 大幅快速运动**时可能出现拖影/重影，**用 6~8 步基本消除**。 |
| `minimax_h3_turbo_v1_850_ema.safetensors` | v1 线（约 850 步）。仅在"**4 步且运动剧烈**"这一个窄场景下比 v4 更友好。名字以 LoRA 仓库实际文件名为准。 |
| `minimax_h3_turbo_4step_ema_ckpt500.safetensors` | 示例工作流 `minimax_h3_t2v_turbo.json` 里默认引用的那一版（ckpt500）。想直接跑通示例工作流就放它。 |

> 一个 LoRA 文件即可覆盖所有 base 变体：节点会自动识别 pruned base，并在运行时重新注入
> LoRA 的时间条件（仓库里自带 `h3_silu_temb_grid.safetensors` 用于此）。

### 1.2 MiniMax-H3 基础模型 / VAE / 文本编码器

来源：**官方 MiniMax-H3 教程** —— <https://docs.comfy.org/tutorials/video/minimax/minimax-h3>
（官方发布页会给出各文件的下载地址；Turbo LoRA 只是加速，**基础模型仍然必需**。）

以下文件名取自本机示例工作流 `minimax_h3_t2v_turbo.json` 的实际引用，可直接照抄目录：

| 文件名 | 放置目录 | 加载节点 | 说明 |
| --- | --- | --- | --- |
| `minimax_h3_fl2va_int8_convrot.safetensors` | `models\diffusion_models\` | `UNETLoader` | 主扩散模型（int8_convrot 量化版；官方另有 `bf16` / `pruned_int8` / `pruned_fp8` 变体） |
| `qwen3vl_32b_minimax_h3_int8_convrot.safetensors` | `models\text_encoders\` | `CLIPLoader` | Qwen3-VL 32B 文本编码器 |
| `minimax_h3_video_vae_fp16.safetensors` | `models\vae\` | `VAELoader` | 视频 VAE |
| `minimax_h3_audio_vae_fp32.safetensors` | `models\vae\` | `VAELoader` | 音频 VAE（同步音频需要） |

### 1.3 推理参数速记（上游 README 要点）

- 步数：**4~8**（4 是推荐下限；6~8 明显更好；超过 8 无收益且会过锐），调度器选 `simple`；
- `strength` 保持 **1.0**（仅个别片段需要微调：拖影 → 调到 `1.05~1.2`；过锐 → 调到 `0.8~0.95`）；
- 分辨率：宽高为 **32 的倍数**，短边通常 768；帧数按 **17k+5** 对齐，24 fps，`124 ≈ 5 秒`，验证范围约 124~362 帧；
- `low_vram` 开关：**off（默认）** 最锐利、峰值显存略高；**on** 合并 LoRA 进权重，峰值显存最低，但在量化 base 上画面偏软；显存不够时打开它或降分辨率/帧数；
- 本机 12 GB 显存属于偏小，建议**先跑小分辨率 + 124 帧**验证链路。

## 2. 其他模型

本机目前**尚未**放置除 MiniMax-H3 之外的模型。后续新增时请在此处补一行：文件名 / 目录 / 来源 URL。

| 文件名 | 放置目录 | 来源 |
| --- | --- | --- |
| （待补充） | | |

## 3. 目录速查

| 目录 | 放什么 |
| --- | --- |
| `models\checkpoints\` | 完整 checkpoint（`.safetensors` / `.ckpt`） |
| `models\diffusion_models\` | 单独的扩散模型（UNETLoader 用） |
| `models\text_encoders\` | 文本编码器（CLIPLoader 用；旧版 ComfyUI 为 `models\clip\`） |
| `models\vae\` | VAE |
| `models\loras\` | LoRA |
| `models\vae_approx\` | TAESD 预览解码器（配 `--preview-method taesd` 用高质量预览） |
| `models\upscale_models\` | 放大模型 |
| `models\controlnet\` | ControlNet |

## 4. 核对命令

列出各目录下已就位的权重文件：

```bat
cd /d <仓库根>\models
dir /s /b *.safetensors *.ckpt *.pt *.gguf
```

只想核对 MiniMax-H3 这一组是否齐全：

```bat
cd /d <仓库根>\models
dir /b diffusion_models\minimax_h3_*.safetensors
dir /b text_encoders\qwen3vl_32b_minimax_h3_*.safetensors
dir /b vae\minimax_h3_*.safetensors
dir /b loras\minimax_h3_turbo_*.safetensors
```

## 5. 共享模型目录（可选）

想让 ComfyUI 复用其他 UI（如 A1111/WebUI）的模型，可把
`<仓库根>\extra_model_paths.yaml.example` 复制为 `extra_model_paths.yaml` 并编辑路径。
该文件是上游提供的示例，改动请放在 `custom/` 下另存一份说明。
