import numpy as np
from scipy.io import wavfile
import os

# 自动推导路径：脚本所在目录 -> 退两级到工程根目录 -> 进入 workspace
script_dir = os.path.dirname(os.path.abspath(__file__))
workspace_dir = os.path.abspath(os.path.join(script_dir, '../../workspace'))

# 读取同目录下的歌 (确保你有这个文件)
samplerate, data = wavfile.read(os.path.join(script_dir, 'test_song.wav'))

# 单声道处理 & 截取前 1 秒
if len(data.shape) > 1:
    data = data[:, 0]
num_samples = min(len(data), samplerate * 1) 
data = data[:num_samples]

# 模拟 ADC: 归一化并映射到 0~255 (中心点在 128)
data_normalized = data / np.max(np.abs(data))
data_8bit = np.clip((data_normalized + 1.0) * 127.5, 0, 255).astype(np.uint8)

# 输出到 workspace
out_path = os.path.join(workspace_dir, 'audio_in.txt')
with open(out_path, 'w') as f:
    for val in data_8bit:
        f.write(f"{val:02X}\n")

print(f"✅ 成功！数据已生成至: {out_path}")