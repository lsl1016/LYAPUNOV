"""
plot2_timeseries_comparison.py - 时序性能对比折线图

包含两组独立的折线图：
第一组：四种调度算法的时序性能对比（统一使用背包缓存算法）
第二组：五种缓存算法的时序性能对比（使用李雅普诺夫调度算法）

"""

import numpy as np
import matplotlib.pyplot as plt

try:
    from .font_config import setup_chinese_font
except ImportError:
    from font_config import setup_chinese_font

#导入日志工具
try:
    from .logger import logger
except ImportError:
    from logger import logger

setup_chinese_font()

# 禁用日志记录（读写文件，非常耗时）
logger.set_enable_log(True)

try:
    from .constants import Constants
    from .simulator import Simulator
except ImportError:
    from constants import Constants
    from simulator import Simulator


def plot2_timeseries_comparison():
    """时序性能对比实验"""
    print('=== 开始时序性能对比实验 ===')
    
    # 第一组实验：四种调度算法对比
    print('\n--- 第一组：调度算法对比 ---')
    plot_scheduling_algorithms_comparison()
    
    # 第二组实验：五种缓存算法对比
    print('\n--- 第二组：缓存算法对比 ---')
    plot_cache_algorithms_comparison()
    
    print('=== 时序性能对比实验完成 ===')


def plot_scheduling_algorithms_comparison():
    """第一组：横坐标为时隙（0——Tsolt），纵坐标分别为MEC时间平均收益、任务积压队列的平均长度
    图例为：四种调度算法，缓存更新统一使用背包算法，最后一种调度应该是不启用缓存的"""
    
    # 导入必要的库
    import random
    import numpy as np
    
    # 实验参数设置
    total_time_slots = 1000      # 仿真时隙数
    Constants.K(40)             # 任务类型数量
    Constants.N(80)             # 每时隙生成任务数
    num_runs = 1                # 多次实验取平均
    print(f'进行 {num_runs} 次独立实验并取平均结果...')
    
    # 调度算法设置
    scheduling_algorithms = [
        Constants.GreedySchedule,      # 贪心调度
        Constants.ShortTermSchedule,   # 短期调度
        Constants.LyapunovSchedule,    # 李雅普诺夫调度
        Constants.NoCacheSchedule      # 无缓存调度
    ]
    
    algorithm_names = [
        '贪心调度+背包缓存',
        '短期调度+背包缓存',
        '李雅普诺夫调度+背包缓存',
        '无缓存调度'
    ]
    
    # 定义线型和标记符号（参考绘图样式模板）
    line_styles = ['-', '-.', '--', ':']
    markers = ['+', 'o', '*', 'x']
    line_width = 1.4
    
    num_algorithms = len(scheduling_algorithms)
    
    # 存储所有实验运行的时序数据
    all_runs_revenue = np.zeros((num_runs, num_algorithms, total_time_slots))
    all_runs_backlog = np.zeros((num_runs, num_algorithms, total_time_slots))

    # 进行多次独立实验
    for run in range(num_runs):
        print(f'\n--- 第 {run + 1}/{num_runs} 次实验 ---')
        logger.info(f'第 {run + 1}/{num_runs} 次实验 ---')
        # 运行仿真实验
        for alg_idx, algorithm in enumerate(scheduling_algorithms):
            alg_name = algorithm_names[alg_idx]
            
            print(f'  测试调度算法: {alg_name} ({alg_idx+1}/{num_algorithms})...')
            logger.info(f'  测试调度算法: {alg_name} ({alg_idx+1}/{num_algorithms})...')
            # 不同的实验运行使用不同的随机种子
            # 但在同一次运行中，所有算法面对相同的环境和任务
            run_seed = 12 + run
            random.seed(run_seed)
            np.random.seed(run_seed)
            
            # 创建仿真器
            sim = Simulator(total_time_slots)
            
            # 设置调度策略
            sim.set_schedule_strategy(algorithm, Constants.VV_DEFAULT)
            
            # 设置缓存策略（无缓存调度除外）
            if algorithm != Constants.NoCacheSchedule:
                sim.set_cache_strategy(Constants.Knapsack)
            else:
                sim.MEC.set_cache_enabled(False)
            # 运行仿真并记录每个时隙的数据
            sim.MEC.update_time_slot(0)
            
            for t in range(total_time_slots):
                sim.CurrentTimeSlot = t
                sim.run_time_slot()
                
                # 记录当前时隙的数据
                all_runs_revenue[run, alg_idx, t] = sim.Statistics.AverageRevenue
                
                # 当前时隙的积压队列总长度
                total_backlog = 0
                K = Constants.K()
                for k in range(1, K + 1):
                    total_backlog += sim.TaskManager.get_backlog_count(k)
                all_runs_backlog[run, alg_idx, t] = total_backlog 
            
            print(f'    完成，最终平均收益: {all_runs_revenue[run, alg_idx, -1]:.4f}, '
                  f'最终平均积压长度: {all_runs_backlog[run, alg_idx, -1]:.2f}')

    # 计算平均结果
    time_series_revenue = np.mean(all_runs_revenue, axis=0)
    time_series_backlog = np.mean(all_runs_backlog, axis=0)
    print('\n=== 所有实验的平均结果计算完成 ===')
    
    # 绘制第一组图：MEC时间平均收益
    plt.figure(figsize=(8, 7))  # 设置为正方形
    time_slots = np.arange(1, total_time_slots + 1)
    
    # 定义颜色方案（参考截图样式）
    colors = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728']
    
    for alg_idx in range(num_algorithms):
        # 每50个点显示一个标记
        marker_indices = list(range(0, total_time_slots, 50))
        plt.plot(time_slots, time_series_revenue[alg_idx, :],
                 label=algorithm_names[alg_idx],
                 linestyle=line_styles[alg_idx],
                 linewidth=line_width,
                 marker=markers[alg_idx],
                 markevery=marker_indices,
                 markersize=6,
                 color=colors[alg_idx])
    
    plt.xlabel('Time slot', fontsize=22)
    plt.ylabel('MEC time average revenue', fontsize=22)
    # 去除标题
    legend = plt.legend(loc='best', fontsize=14)
    legend.get_frame().set_edgecolor('black')
    legend.get_frame().set_linewidth(1.0)
    plt.grid(True)
    
    # 设置坐标轴刻度字体大小
    plt.xticks(fontsize=14)
    plt.yticks(fontsize=14)
    
    # 设置外边框为实线
    ax = plt.gca()
    for spine in ax.spines.values():
        spine.set_linewidth(1.0)
        spine.set_linestyle('-')
    
    plt.tight_layout()
    plt.show()
    
    # 绘制第一组图：任务积压队列的平均长度
    plt.figure(figsize=(8, 7))  # 设置为正方形
    
    for alg_idx in range(num_algorithms):
        marker_indices = list(range(0, total_time_slots, 50))
        plt.plot(time_slots, time_series_backlog[alg_idx, :],
                 label=algorithm_names[alg_idx],
                 linestyle=line_styles[alg_idx],
                 linewidth=line_width,
                 marker=markers[alg_idx],
                 markevery=marker_indices,
                 markersize=6,
                 color=colors[alg_idx])
    
    plt.xlabel('Time slot', fontsize=22)
    plt.ylabel('Backlog queue length', fontsize=22)
    # 去除标题
    legend = plt.legend(loc='best', fontsize=14)
    legend.get_frame().set_edgecolor('black')
    legend.get_frame().set_linewidth(1.0)
    plt.grid(True)
    
    # 设置坐标轴刻度字体大小
    plt.xticks(fontsize=14)
    plt.yticks(fontsize=14)
    
    # 设置外边框为实线
    ax = plt.gca()
    for spine in ax.spines.values():
        spine.set_linewidth(1.0)
        spine.set_linestyle('-')
    
    plt.tight_layout()
    plt.show()
    
    # 保存第一组数据（可选）
    # import pandas as pd
    # results_dict = {'TimeSlot': time_slots}
    # for alg_idx in range(num_algorithms):
    #     clean_name = algorithm_names[alg_idx].replace('+', '_').replace('调度', '')
    #     results_dict[f'Revenue_{clean_name}'] = time_series_revenue[alg_idx, :]
    #     results_dict[f'Backlog_{clean_name}'] = time_series_backlog[alg_idx, :]
    # 
    # results_df = pd.DataFrame(results_dict)
    # filename = f'plot2_group1_scheduling_results_{pd.Timestamp.now().strftime("%Y%m%d_%H%M%S")}.csv'
    # results_df.to_csv(filename, index=False)
    # print(f'第一组结果已保存到文件: {filename}')


def plot_cache_algorithms_comparison():
    """第二组：K=40, N=20, VV=1
    横坐标为时隙（0——Tsolt），纵坐标分别为当前时隙MEC的时间平均收益、任务积压队列的平均长度、MEC缓存的任务类型总价值
    图例为：调度算法使用LyapunovSchedule + 五种不同的缓存更新算法（FIFO、LRU、LFU、Priority、Knapsack）"""
    
    # 导入必要的库
    import random
    import numpy as np
    
    # 实验参数设置
    total_time_slots = 1000      # 仿真时隙数
    Constants.K(40)             # 任务类型数量
    Constants.N(80)             # 每时隙生成任务数
    vv_parameter = 1.0          # 李雅普诺夫参数VV=1
    num_runs = 1                # 多次实验取平均
    print(f'进行 {num_runs} 次独立实验并取平均结果...')
    
    # 缓存算法设置
    cache_algorithms = [
        Constants.FIFO,
        Constants.LRU,
        Constants.LFU,
        Constants.Priority,
        Constants.Knapsack
    ]
    
    cache_names = [
        'FIFO缓存',
        'LRU缓存',
        'LFU缓存',
        'Priority缓存',
        'Knapsack缓存'
    ]
    
    # 定义线型和标记符号
    line_styles = ['-', '-.', '--', ':', '-']
    markers = ['+', 'o', '*', 'x', 's']
    line_width = 1.4
    
    num_cache_algs = len(cache_algorithms)
    
    # 存储所有实验运行的时序数据
    all_runs_revenue = np.zeros((num_runs, num_cache_algs, total_time_slots))
    all_runs_backlog = np.zeros((num_runs, num_cache_algs, total_time_slots))
    all_runs_value = np.zeros((num_runs, num_cache_algs, total_time_slots))

    # 进行多次独立实验
    for run in range(num_runs):
        print(f'\n--- 第 {run + 1}/{num_runs} 次实验 ---')
        # 运行仿真实验
        for cache_idx, cache_alg in enumerate(cache_algorithms):
            cache_name = cache_names[cache_idx]
            
            print(f'  测试缓存算法: {cache_name} ({cache_idx+1}/{num_cache_algs})...')
            
            # 不同的实验运行使用不同的随机种子
            # 但在同一次运行中，所有算法面对相同的环境和任务
            run_seed = 12 + run
            random.seed(run_seed)
            np.random.seed(run_seed)
            
            # 创建仿真器
            sim = Simulator(total_time_slots)
            
            # 设置调度策略为李雅普诺夫调度，VV=1
            sim.set_schedule_strategy(Constants.LyapunovSchedule, vv_parameter)
            
            # 设置缓存策略
            sim.set_cache_strategy(cache_alg)
            
            # 运行仿真并记录每个时隙的数据
            sim.MEC.update_time_slot(0)
            
            for t in range(total_time_slots):
                sim.CurrentTimeSlot = t
                sim.run_time_slot()
                
                # 记录当前时隙的数据
                all_runs_revenue[run, cache_idx, t] = sim.Statistics.AverageRevenue
                
                total_backlog = 0
                K = Constants.K()
                for k in range(1, K + 1):
                    total_backlog += sim.TaskManager.get_backlog_count(k)
                all_runs_backlog[run, cache_idx, t] = total_backlog
                
                # 计算缓存总价值
                all_runs_value[run, cache_idx, t] = sim.MEC.get_cache_total_value(sim.TaskManager)
            
            print(f'    完成，最终平均收益: {all_runs_revenue[run, cache_idx, -1]:.4f}, '
                  f'最终平均积压长度: {all_runs_backlog[run, cache_idx, -1]:.2f}, '
                  f'最终缓存价值: {all_runs_value[run, cache_idx, -1]:.2f}')

    # 计算平均结果
    cache_time_series_revenue = np.mean(all_runs_revenue, axis=0)
    cache_time_series_backlog = np.mean(all_runs_backlog, axis=0)
    cache_time_series_value = np.mean(all_runs_value, axis=0)
    print('\n=== 所有实验的平均结果计算完成 ===')
    
    # 绘制第二组图：MEC时间平均收益
    plt.figure(figsize=(8, 7))  # 设置为正方形
    time_slots = np.arange(1, total_time_slots + 1)
    
    # 定义缓存算法颜色方案（参考截图样式）
    cache_colors = ['#1f77b4', '#ff7f0e', '#ffbb78', '#9467bd', '#c5b0d5']
    
    for cache_idx in range(num_cache_algs):
        marker_indices = list(range(0, total_time_slots, 50))
        plt.plot(time_slots, cache_time_series_revenue[cache_idx, :],
                 label=cache_names[cache_idx],
                 linestyle=line_styles[cache_idx],
                 linewidth=line_width,
                 marker=markers[cache_idx],
                 markevery=marker_indices,
                 markersize=6,
                 color=cache_colors[cache_idx])
    
    plt.xlabel('Time slot', fontsize=22)
    plt.ylabel('MEC time average revenue', fontsize=22)
    # 去除标题
    legend = plt.legend(loc='best', fontsize=14)
    legend.get_frame().set_edgecolor('black')
    legend.get_frame().set_linewidth(1.0)
    plt.grid(True)
    
    # 设置坐标轴刻度字体大小
    plt.xticks(fontsize=14)
    plt.yticks(fontsize=14)
    
    # 设置外边框为实线
    ax = plt.gca()
    for spine in ax.spines.values():
        spine.set_linewidth(1.0)
        spine.set_linestyle('-')
    
    plt.tight_layout()
    plt.show()
    
    # 绘制第二组图：任务积压队列的平均长度
    plt.figure(figsize=(8, 7))  # 设置为正方形
    
    for cache_idx in range(num_cache_algs):
        marker_indices = list(range(0, total_time_slots, 50))
        plt.plot(time_slots, cache_time_series_backlog[cache_idx, :],
                 label=cache_names[cache_idx],
                 linestyle=line_styles[cache_idx],
                 linewidth=line_width,
                 marker=markers[cache_idx],
                 markevery=marker_indices,
                 markersize=6,
                 color=cache_colors[cache_idx])
    
    plt.xlabel('Time slot', fontsize=22)
    plt.ylabel('Backlog queue length', fontsize=22)
    # 去除标题
    legend = plt.legend(loc='best', fontsize=14)
    legend.get_frame().set_edgecolor('black')
    legend.get_frame().set_linewidth(1.0)
    plt.grid(True)
    
    # 设置坐标轴刻度字体大小
    plt.xticks(fontsize=14)
    plt.yticks(fontsize=14)
    
    # 设置外边框为实线
    ax = plt.gca()
    for spine in ax.spines.values():
        spine.set_linewidth(1.0)
        spine.set_linestyle('-')
    
    plt.tight_layout()
    plt.show()
    
    # 绘制第二组图：MEC缓存的任务类型总价值
    plt.figure(figsize=(8, 7))  # 设置为正方形
    
    for cache_idx in range(num_cache_algs):
        marker_indices = list(range(0, total_time_slots, 50))
        plt.plot(time_slots, cache_time_series_value[cache_idx, :],
                 label=cache_names[cache_idx],
                 linestyle=line_styles[cache_idx],
                 linewidth=line_width,
                 marker=markers[cache_idx],
                 markevery=marker_indices,
                 markersize=6,
                 color=cache_colors[cache_idx])
    
    plt.xlabel('Time slot', fontsize=22)
    plt.ylabel('MEC cache total value', fontsize=22)
    # 去除标题
    legend = plt.legend(loc='best', fontsize=14)
    legend.get_frame().set_edgecolor('black')
    legend.get_frame().set_linewidth(1.0)
    plt.grid(True)
    
    # 设置坐标轴刻度字体大小
    plt.xticks(fontsize=14)
    plt.yticks(fontsize=14)
    
    # 设置外边框为实线
    ax = plt.gca()
    for spine in ax.spines.values():
        spine.set_linewidth(1.0)
        spine.set_linestyle('-')
    
    plt.tight_layout()
    plt.show()
    
    # 保存第二组数据（可选）
    # import pandas as pd
    # results_dict = {'TimeSlot': time_slots}
    # for cache_idx in range(num_cache_algs):
    #     clean_name = cache_names[cache_idx].replace('缓存', '')
    #     results_dict[f'Revenue_{clean_name}'] = cache_time_series_revenue[cache_idx, :]
    #     results_dict[f'Backlog_{clean_name}'] = cache_time_series_backlog[cache_idx, :]
    #     results_dict[f'CacheValue_{clean_name}'] = cache_time_series_value[cache_idx, :]
    # 
    # results_df = pd.DataFrame(results_dict)
    # filename = f'plot2_group2_cache_results_{pd.Timestamp.now().strftime("%Y%m%d_%H%M%S")}.csv'
    # results_df.to_csv(filename, index=False)
    # print(f'第二组结果已保存到文件: {filename}')


if __name__ == "__main__":
    plot2_timeseries_comparison()
