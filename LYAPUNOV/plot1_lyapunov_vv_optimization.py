"""
plot1_lyapunov_vv_optimization.py - 李雅普诺夫漂移参数VV优化折线图

目的：寻找合适的李雅普诺夫漂移参数VV
参数设置：K=20, N=20, 调度算法使用LyapunovSchedule, 缓存算法使用Knapsack
横坐标：VV（李雅普诺夫漂移参数）
纵坐标：MEC的时间平均收益

从MATLAB版本转换而来，保留所有原始逻辑和注释
"""

import numpy as np
import matplotlib.pyplot as plt

# 配置中文字体支持
try:
    from .font_config import setup_chinese_font
except ImportError:
    from font_config import setup_chinese_font

# 设置中文字体
setup_chinese_font()

# 处理导入问题
try:
    from .constants import Constants
    from .simulator import Simulator
except ImportError:
    from constants import Constants
    from simulator import Simulator


def plot1_lyapunov_vv_optimization():
    """李雅普诺夫参数VV优化实验"""
    print('=== 开始李雅普诺夫参数VV优化实验 ===')
    
    # 导入必要的库
    import random
    
    # 实验参数设置
    Constants.K(20)           # 设置任务类型数量为20
    Constants.N(20)           # 设置每时隙生成任务数为20
    total_time_slots = 1000   # 仿真时隙数
    
    # VV参数范围设置
    vv_range = [0.5, 1.0, 2.0, 4.0, 6.0, 8.0, 10.0, 12.0, 15.0, 20.0]
    num_vv = len(vv_range)
    
    # 存储结果
    average_revenues = np.zeros(num_vv)
    
    # 对每个VV值进行仿真
    for i, current_vv in enumerate(vv_range):
        print(f'正在测试VV = {current_vv:.1f} ({i+1}/{num_vv})...')
        
        # 设置固定随机种子，确保所有VV值面对相同的环境和任务
        random.seed(42)  # 所有VV值使用相同的种子
        np.random.seed(42)
        
        # 创建仿真器
        sim = Simulator(total_time_slots)
        
        # 设置调度策略为李雅普诺夫调度，缓存策略为背包算法
        sim.set_schedule_strategy(Constants.LyapunovSchedule, current_vv)
        sim.set_cache_strategy(Constants.Knapsack)
        
        # 运行仿真（静默模式，不输出进度）
        try:
            # 临时重定向输出（Python版本简化处理）
            original_print = print
            import builtins
            builtins.print = lambda *args, **kwargs: None  # 临时禁用print
            
            sim.run_simulation()
            
            # 恢复print
            builtins.print = original_print
        except Exception as e:
            builtins.print = original_print  # 确保恢复print
            print(f'仿真过程中出错: {e}')
            continue
        
        # 获取统计结果
        stats = sim.get_statistics()
        average_revenues[i] = stats.AverageRevenue
        
        print(f'VV = {current_vv:.1f}, 时间平均收益 = {average_revenues[i]:.4f}')
    
    # 绘制折线图
    plt.figure(figsize=(8, 8))  # 设置为正方形
    
    # 定义线型和标记符号（参考绘图样式模板）
    line_style = '-'
    marker = 'o'
    line_width = 1.4
    
    # 绘制折线图
    plt.plot(vv_range, average_revenues,
             label='MEC时间平均收益',
             linestyle=line_style,
             linewidth=line_width,
             marker=marker,
             markersize=6,
             markerfacecolor='auto',
             color='#1f77b4')  # 使用标准蓝色
    
    # 图形设置
    plt.xlabel('李雅普诺夫漂移参数 VV')
    plt.ylabel('MEC时间平均收益')
    # 去除标题
    plt.grid(True)
    plt.legend()
    
    # 设置外边框为实线
    ax = plt.gca()
    for spine in ax.spines.values():
        spine.set_linewidth(1.0)
        spine.set_linestyle('-')
    
    # 找出最优VV值
    max_idx = np.argmax(average_revenues)
    optimal_vv = vv_range[max_idx]
    max_revenue = average_revenues[max_idx]
    
    # 在图上标注最优点
    plt.plot(optimal_vv, max_revenue, 'r*', markersize=12, linewidth=2)
    plt.text(optimal_vv, max_revenue + max_revenue * 0.05,
             f'最优VV = {optimal_vv:.1f}\n收益 = {max_revenue:.4f}',
             horizontalalignment='center', fontsize=10, color='red')
    
    # 输出结果摘要
    print('\n=== VV优化实验结果摘要 ===')
    print(f'测试的VV范围: [{min(vv_range):.1f}, {max(vv_range):.1f}]')
    print(f'最优VV值: {optimal_vv:.1f}')
    print(f'最优收益: {max_revenue:.4f}')
    print(f'收益提升: {(max_revenue - min(average_revenues)) / min(average_revenues) * 100:.2f}%')
    
    # 保存结果数据（可选）
    # import pandas as pd
    # results_df = pd.DataFrame({
    #     'VV_Parameter': vv_range,
    #     'Average_Revenue': average_revenues
    # })
    # 
    # filename = f'vv_optimization_results_{pd.Timestamp.now().strftime("%Y%m%d_%H%M%S")}.csv'
    # results_df.to_csv(filename, index=False)
    # print(f'结果已保存到文件: {filename}')
    
    # 保存图形（可选）
    # plt.savefig(f'plot1_vv_optimization_{pd.Timestamp.now().strftime("%Y%m%d_%H%M%S")}.png', 
    #             dpi=300, bbox_inches='tight')
    # print('图形已保存')
    
    plt.tight_layout()
    plt.show()
    
    print('=== VV优化实验完成 ===')
    
    return {
        'vv_range': vv_range,
        'average_revenues': average_revenues,
        'optimal_vv': optimal_vv,
        'max_revenue': max_revenue
    }


if __name__ == "__main__":
    plot1_lyapunov_vv_optimization()
