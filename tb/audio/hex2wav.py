import numpy as np
from scipy.io import wavfile
import os

script_dir = os.path.dirname(os.path.abspath(__file__))
workspace_dir = os.path.abspath(os.path.join(script_dir, '../../workspace'))

in_path = os.path.join(workspace_dir, 'audio_out.txt')
out_path = os.path.join(script_dir, 'fpga_processed_song.wav')

out_data = []
with open(in_path, 'r') as f:
    for line in f:
        val_str = line.strip()
        # 跳过未初始化的波形数据
        if 'x' in val_str.lower() or 'z' in val_str.lower():
            out_data.append(2048) 
        else:
            out_data.append(int(val_str, 16))

# 去除 2048 偏置，还原波形
out_data = np.array(out_data, dtype=np.float32)
out_data = out_data - 2048.0 

# 转回 16-bit 音频格式
out_data_normalized = np.int16(out_data / np.max(np.abs(out_data)) * 32767)

wavfile.write(out_path, 40000, out_data_normalized)
print(f"🎧 搞定！验收神曲已生成至: {out_path}")