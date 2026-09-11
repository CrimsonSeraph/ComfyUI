# workflows/ — 特化工作流 JSON

本目录存放本机自己维护/调好的 ComfyUI 工作流（`.json`），以及它们的来源与改动说明。

> ComfyUI 界面里 `Workflow → Export` 导出的就是可直接拖进画布的 JSON；
> 生成的 PNG 里也会内嵌工作流，拖回界面即可还原（含种子）。

## 目录约定

| 位置 | 用途 |
| --- | --- |
| `custom\workflows\`（本目录） | **你自己特化/调参后**的工作流。改了参数、换了模型、精简了节点，都放这里 |
| `custom_nodes\<节点>\example_workflows\` | 自定义节点**上游自带**的示例工作流，随节点更新而变化，**不要在这里改** |

命名建议：`<模型>_<任务>_<要点>.json`，例如 `minimax_h3_t2v_turbo_v4_6step.json`。

## 已登记工作流

| 文件 | 来源 | 说明 |
| --- | --- | --- |
| （本目录暂无文件） | | |
| ↗ 参考：`custom_nodes\ComfyUI-MiniMax-H3-Turbo\example_workflows\minimax_h3_t2v_turbo.json` | 上游节点自带 | MiniMax-H3 文生视频 + 同步音频，含 Turbo LoRA 直连。引用的模型见 [`../models/README.md`](../models/README.md) |

## 把上游示例变成自己的特化版本

```bat
cd /d <仓库根>
copy custom_nodes\ComfyUI-MiniMax-H3-Turbo\example_workflows\minimax_h3_t2v_turbo.json custom\workflows\minimax_h3_t2v_turbo_v4_6step.json
```

然后在界面里加载这个副本，按需调参（例如 LoRA 换成 v4、步数改 6、分辨率/帧数按 12 GB 显存下调），
再 `Export` 覆盖保存回本目录。这样上游节点更新示例时不会覆盖你的调参结果。

## 工作流里会引用模型文件名

工作流 JSON 里记录的是**模型文件名**（不是绝对路径）。换机器或换模型版本后，
必须保证 [`../models/README.md`](../models/README.md) 中登记的对应文件真实存在于相应目录，
否则加载工作流时节点会报"找不到模型"。

MiniMax-H3 Turbo 示例工作流引用的文件（取自该 JSON 实际内容）：

| 加载节点 | 文件名 | 目录 |
| --- | --- | --- |
| `UNETLoader` | `minimax_h3_fl2va_int8_convrot.safetensors` | `models\diffusion_models\` |
| `CLIPLoader` | `qwen3vl_32b_minimax_h3_int8_convrot.safetensors` | `models\text_encoders\` |
| `VAELoader` | `minimax_h3_video_vae_fp16.safetensors` | `models\vae\` |
| `VAELoader` | `minimax_h3_audio_vae_fp32.safetensors` | `models\vae\` |
| `MiniMaxH3TurboLoRA` | `minimax_h3_turbo_4step_ema_ckpt500.safetensors` | `models\loras\` |

## 相关上游资料

- MiniMax-H3 官方教程：<https://docs.comfy.org/tutorials/video/minimax/minimax-h3>
- Turbo LoRA / 节点：<https://github.com/Larryvrh/ComfyUI-MiniMax-H3-Turbo>
- 官方工作流模板库（界面里的 Templates）：<https://comfy.org/workflows/>
