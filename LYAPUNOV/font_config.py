"""
中文字体配置模块
解决matplotlib中文显示问题
"""

import matplotlib.pyplot as plt
import matplotlib
from matplotlib.font_manager import FontProperties
import platform
import os


def setup_chinese_font():
    """设置中文字体支持"""
    
    # 检测操作系统
    system = platform.system()
    
    if system == 'Windows':
        # Windows系统常见中文字体
        chinese_fonts = [
            'SimHei',           # 黑体
            'Microsoft YaHei',  # 微软雅黑
            'SimSun',           # 宋体
            'KaiTi',            # 楷体
            'FangSong'          # 仿宋
        ]
    elif system == 'Darwin':  # macOS
        chinese_fonts = [
            'Heiti TC',         # 黑体-繁
            'Arial Unicode MS', # Arial Unicode MS
            'PingFang SC',      # 苹方-简
            'STHeiti'           # 华文黑体
        ]
    else:  # Linux
        chinese_fonts = [
            'WenQuanYi Micro Hei',  # 文泉驿微米黑
            'DejaVu Sans',          # DejaVu Sans
            'SimHei'                # 黑体
        ]
    
    # 尝试设置可用的中文字体
    font_set = False
    for font_name in chinese_fonts:
        try:
            # 测试字体是否可用
            font_prop = FontProperties(fname=None)
            font_prop.set_family(font_name)
            
            # 设置matplotlib的中文字体
            plt.rcParams['font.sans-serif'] = [font_name] + plt.rcParams['font.sans-serif']
            plt.rcParams['axes.unicode_minus'] = False  # 解决负号显示问题
            
            print(f"成功设置中文字体: {font_name}")
            font_set = True
            break
            
        except Exception as e:
            continue
    
    if not font_set:
        print("警告: 未找到合适的中文字体，将使用系统默认字体")
        # 设置基本的unicode支持
        plt.rcParams['axes.unicode_minus'] = False
    
    return font_set


def get_available_chinese_fonts():
    """获取系统中可用的中文字体列表"""
    from matplotlib.font_manager import fontManager
    
    chinese_fonts = []
    for font in fontManager.ttflist:
        font_name = font.name
        # 检查是否包含中文字符支持
        if any(chinese_char in font_name for chinese_char in ['黑体', '宋体', '楷体', '仿宋', '雅黑']):
            chinese_fonts.append(font_name)
        elif font_name in ['SimHei', 'SimSun', 'KaiTi', 'FangSong', 'Microsoft YaHei', 
                          'Heiti TC', 'PingFang SC', 'WenQuanYi Micro Hei']:
            chinese_fonts.append(font_name)
    
    return list(set(chinese_fonts))


def test_chinese_display():
    """测试中文显示效果"""
    import numpy as np
    
    # 创建测试图形
    fig, ax = plt.subplots(figsize=(10, 6))
    
    # 测试数据
    x = np.array([1, 2, 3, 4, 5])
    y = np.array([2, 4, 6, 8, 10])
    
    # 绘制图形
    ax.plot(x, y, 'o-', label='测试数据')
    ax.set_xlabel('横坐标')
    ax.set_ylabel('纵坐标')
    ax.set_title('中文字体测试图表')
    ax.legend()
    ax.grid(True)
    
    # 添加中文文本注释
    ax.text(3, 6, '这是中文文本测试', fontsize=12, ha='center')
    
    plt.tight_layout()
    plt.show()
    
    print("中文字体测试完成！")


if __name__ == "__main__":
    print("=== 中文字体配置测试 ===")
    
    # 显示可用字体
    available_fonts = get_available_chinese_fonts()
    print(f"系统中可用的中文字体: {available_fonts}")
    
    # 设置中文字体
    setup_chinese_font()
    
    # 测试中文显示
    test_chinese_display()
