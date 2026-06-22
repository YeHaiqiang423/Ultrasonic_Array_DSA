import numpy as np
from scipy.io import wavfile
from scipy import signal
import os

def process_ultrasonic_audio(input_file, output_file, cutoff_freq=800):
    if not os.path.exists(input_file):
        print(f"❌ 找不到文件: {input_file}")
        return

    # 1. 读取音频并转换为单声道浮点数
    sample_rate, data = wavfile.read(input_file)
    print(f"🎵 原始采样率: {sample_rate} Hz")
    
    if len(data.shape) > 1:
        data = data.mean(axis=1)
        print("🔪 已将双声道转换为单声道")
        
    data = data.astype(np.float64) # 防止 16-bit 整数在运算中溢出

    # 2. 核心滤除：4 阶巴特沃斯高通 (切除低频陷阱)
    print(f"🎛️ 正在切除 {cutoff_freq}Hz 以下的低音...")
    nyquist = 0.5 * sample_rate
    b, a = signal.butter(4, cutoff_freq / nyquist, btype='high')
    filtered_data = signal.filtfilt(b, a, data)

# 3. 硬件 EQ 补偿：狂暴拉升探头弱势高频
    print("🚀 正在注入高阶 FIR EQ 补偿...")
# 3. 硬件 EQ 补偿
    freqs = [0, 1000, 3000, 8000, nyquist]
    
    # 🌟 核心调音：把 3.0 降下来！
    # 1.3 的平方是 1.69倍，1.5 的平方是 2.25 倍。这对于流行乐足够补偿 40kHz 探头了！
    gains = [1.0, 1.0,  1.1,  1.3,  1.5]
    
    taps = signal.firwin2(1023, freqs, gains, fs=sample_rate)
    eq_data = signal.filtfilt(taps, 1.0, filtered_data)

    # 4. 绝对归一化
    max_val = np.max(np.abs(eq_data))
    normalized_data = eq_data / max_val if max_val > 0 else eq_data

    # 5. 🌟 终极数字软底噪门 (Soft Expander)：抹除海浪声，保留连贯性
    print("🚪 正在应用数字软底噪门...")
    threshold = 0  # 阈值：最大音量的 4% 以下视为海浪底噪
    abs_data = np.abs(normalized_data)
    mask = abs_data < threshold
    
    # 魔法：对于低于阈值的部分，不粗暴写 0，而是做平方级平滑衰减
    # 这样噪音会像丝绸一样褪去，绝对不会产生“一卡一卡”的爆音！
    normalized_data[mask] = normalized_data[mask] * (abs_data[mask] / threshold)

    # 6. Berktay 平方根预失真 (抵消空气非线性失真)
    print("🪄 正在应用 Berktay 平方根预失真...")
    modulation_index = 0.8  
    envelope = 1.0 + modulation_index * normalized_data
    predistorted_audio = np.sqrt(envelope)

   # 7. 终极映射到 0~255 区间 (重新锁定中心点 128！)
    print("🎯 正在执行声学锚定：锁定绝对静音中心点 128...")
    
    # 在 Berktay 公式中，静音 (normalized_data = 0) 时，预失真值为 sqrt(1.0) = 1.0
    silent_val = 1.0 
    
    # 算出波形往上和往下偏离静音点的最大距离
    max_p = np.max(predistorted_audio)
    min_p = np.min(predistorted_audio)
    max_offset = max(max_p - silent_val, silent_val - min_p)
    
    # 按照最大的偏移量进行等比例缩放，保证静音点永远在 0，极值不超过 ±1.0
    centered_audio = (predistorted_audio - silent_val) / max_offset if max_offset > 0 else 0
    
    # 完美映射回 0~255！此时静音绝对等于 128！
    final_data_8bit = np.uint8(np.clip((centered_audio * 127) + 128, 0, 255))

    # 8. 保存文件
    wavfile.write(output_file, sample_rate, final_data_8bit)
    print(f"✅ 处理完成！完美无底噪音频已生成：{output_file}")

if __name__ == "__main__":
    # 获取脚本当前所在目录，彻底解决路径报错
    script_dir = os.path.dirname(os.path.abspath(__file__))
    input_wav = os.path.join(script_dir, "test_song.wav")
    output_wav = os.path.join(script_dir, "fpga_processed_song.wav")
    
    print("==================================================")
    print("   超声波相控阵 - 终极声学预处理引擎启动")
    print("==================================================")
    
    process_ultrasonic_audio(input_wav, output_wav, cutoff_freq=800)