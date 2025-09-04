"""
plot4_cache_strategy_comparison.py - 缓存策略性能对比柱状图

包含两组独立的柱状图：
第一组：不同任务类型数量K下的缓存策略性能对比（N=20）
第二组：不同任务生成数量N下的缓存策略性能对比（K=50）

纵坐标包括：MEC时间平均收益、任务积压队列平均长度、MEC缓存任务类型总价值、
缓存命中率、缓存命中任务总优先级
图例为：调度算法使用LyapunovSchedule + 五种不同的缓存更新算法
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


def plot4_cache_strategy_comparison():
    """缓存策略性能对比实验"""
    print('=== 开始缓存策略性能对比实验 ===')
    
    # 第一组实验：不同任务类型数量K下的缓存策略对比
    print('\n--- 第一组：不同任务类型数量K下的缓存策略对比 ---')
    plot_cache_strategies_vs_k()
    
    # 第二组实验：不同任务生成数量N下的缓存策略对比
    print('\n--- 第二组：不同任务生成数量N下的缓存策略对比 ---')
    plot_cache_strategies_vs_n()
    
    print('=== 缓存策略性能对比实验完成 ===')


def plot_cache_strategies_vs_k():
    """第一组：
    横坐标取不同的任务类型 k= [40,50,60,70,80], 单时隙的产生任务数量 N=20
    纵坐标分别为（所有时隙的） MEC的时间平均收益（总收入/总时隙）、任务积压队列的平均长度（所有任务类型的总积压长度/总时隙）、MEC缓存的任务类型总价值，
    所有时隙的缓存命中率、所有时隙的所有任务缓存命中任务总优先级
    图例为：调度算法使用LyapunovSchedule + 五种不同的缓存更新算法（FIFO、LRU、LFU、Priority、Knapsack）"""
    
    # 导入必要的库
    import random
    import numpy as np
    
    # 实验参数设置
    k_values = [40, 50, 60, 70, 80]
    fixed_n = 20
    total_time_slots = 500
    Constants.total_cache_size(1000)
    num_runs = 5  # 多次实验取平均
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
    
    num_k = len(k_values)
    num_cache_algs = len(cache_algorithms)
    
    # 存储所有运行的结果
    all_runs_revenue = np.zeros((num_runs, num_cache_algs, num_k))
    all_runs_backlog = np.zeros((num_runs, num_cache_algs, num_k))
    all_runs_cache_value = np.zeros((num_runs, num_cache_algs, num_k))
    all_runs_hit_rate = np.zeros((num_runs, num_cache_algs, num_k))
    all_runs_hit_priority = np.zeros((num_runs, num_cache_algs, num_k))

    # 进行多次独立实验
    for run in range(num_runs):
        print(f'\n--- 第 {run + 1}/{num_runs} 次实验 ---')
        # 运行仿真实验
        for k_idx, current_k in enumerate(k_values):
            Constants.K(current_k)        # 设置任务类型数量
            Constants.N(fixed_n)          # 设置每时隙生成任务数
            
            print(f'  正在测试K={current_k} ({k_idx+1}/{num_k})...')
            
            for cache_idx, cache_alg in enumerate(cache_algorithms):
                cache_name = cache_names[cache_idx]
                
                # print(f'  缓存算法: {cache_name} ({cache_idx+1}/{num_cache_algs})') # 静默模式
                
                # 不同的实验运行使用不同的随机种子
                # 但在同一次运行中，所有算法和参数面对相同的环境和任务
                run_seed = 42 + run
                random.seed(run_seed)
                np.random.seed(run_seed)
                
                # 创建仿真器
                sim = Simulator(total_time_slots)
                
                # 设置调度策略为李雅普诺夫调度
                sim.set_schedule_strategy(Constants.LyapunovSchedule, Constants.VV_DEFAULT)
                
                # 设置缓存策略
                sim.set_cache_strategy(cache_alg)
                
                # 运行仿真（静默模式）
                try:
                    original_print = print
                    import builtins
                    builtins.print = lambda *args, **kwargs: None
                    
                    sim.run_simulation()
                    
                    builtins.print = original_print
                except Exception as e:
                    builtins.print = original_print
                    print(f'    仿真过程中出错: {e}')
                    continue
                
                # 获取统计结果
                stats = sim.get_statistics()
                all_runs_revenue[run, cache_idx, k_idx] = stats.AverageRevenue
                all_runs_backlog[run, cache_idx, k_idx] = stats.AverageBacklogQueueLength
                all_runs_cache_value[run, cache_idx, k_idx] = sim.MEC.get_cache_total_value(sim.TaskManager)
                if stats.TotalCacheAccess > 0:
                    all_runs_hit_rate[run, cache_idx, k_idx] = stats.CacheHitCount / stats.TotalCacheAccess * 100
                else:
                    all_runs_hit_rate[run, cache_idx, k_idx] = 0
                
                total_hit_priority = 0
                for task_type in stats.TaskTypeStats:
                    stat = stats.TaskTypeStats[task_type]
                    total_hit_priority += stat.CacheHitPrioritySum
                all_runs_hit_priority[run, cache_idx, k_idx] = total_hit_priority

    # 计算平均结果
    results_revenue = np.mean(all_runs_revenue, axis=0)
    results_backlog = np.mean(all_runs_backlog, axis=0)
    results_cache_value = np.mean(all_runs_cache_value, axis=0)
    results_hit_rate = np.mean(all_runs_hit_rate, axis=0)
    results_hit_priority = np.mean(all_runs_hit_priority, axis=0)
    print('\n=== 所有实验的平均结果计算完成 ===')
    
    # 绘制第一组柱状图：MEC时间平均收益
    plt.figure(figsize=(8, 8))  # 设置为正方形
    x = np.arange(len(k_values))
    width = 0.14  # 调整柱子宽度，增加间距
    
    # 定义缓存算法颜色方案（参考截图样式）
    cache_colors = ['#1f77b4', '#ff7f0e', '#ffbb78', '#9467bd', '#c5b0d5']
    
    for i in range(num_cache_algs):
        plt.bar(x + i * width, results_revenue[i, :], width, 
                label=cache_names[i], color=cache_colors[i])
    
    plt.xlabel('任务类型数量 K', fontsize=22)
    plt.ylabel('MEC时间平均收益', fontsize=22)
    # 去除标题
    plt.xticks(x + width * 2, k_values, fontsize=14)
    plt.yticks(fontsize=14)
    legend = plt.legend(loc='best', fontsize=14)
    legend.get_frame().set_edgecolor('black')
    legend.get_frame().set_linewidth(1.0)
    plt.grid(True, alpha=0.3)
    
    # 设置外边框为实线
    ax = plt.gca()
    for spine in ax.spines.values():
        spine.set_linewidth(1.0)
        spine.set_linestyle('-')
    
    plt.tight_layout()
    plt.show()
    
    # 绘制第一组柱状图：任务积压队列的平均长度
    plt.figure(figsize=(8, 8))  # 设置为正方形
    
    for i in range(num_cache_algs):
        plt.bar(x + i * width, results_backlog[i, :], width, 
                label=cache_names[i], color=cache_colors[i])
    
    plt.xlabel('任务类型数量 K', fontsize=22)
    plt.ylabel('任务积压队列的平均长度', fontsize=22)
    # 去除标题
    plt.xticks(x + width * 2, k_values, fontsize=14)
    plt.yticks(fontsize=14)
    legend = plt.legend(loc='best', fontsize=14)
    legend.get_frame().set_edgecolor('black')
    legend.get_frame().set_linewidth(1.0)
    plt.grid(True, alpha=0.3)
    
    # 设置外边框为实线
    ax = plt.gca()
    for spine in ax.spines.values():
        spine.set_linewidth(1.0)
        spine.set_linestyle('-')
    
    plt.tight_layout()
    plt.show()
    
    # 绘制第一组柱状图：MEC缓存的任务类型总价值
    plt.figure(figsize=(8, 8))  # 设置为正方形
    
    for i in range(num_cache_algs):
        plt.bar(x + i * width, results_cache_value[i, :], width, 
                label=cache_names[i], color=cache_colors[i])
    
    plt.xlabel('任务类型数量 K', fontsize=22)
    plt.ylabel('MEC缓存的任务类型总价值', fontsize=22)
    # 去除标题
    plt.xticks(x + width * 2, k_values, fontsize=14)
    plt.yticks(fontsize=14)
    legend = plt.legend(loc='best', fontsize=14)
    legend.get_frame().set_edgecolor('black')
    legend.get_frame().set_linewidth(1.0)
    plt.grid(True, alpha=0.3)
    
    # 设置外边框为实线
    ax = plt.gca()
    for spine in ax.spines.values():
        spine.set_linewidth(1.0)
        spine.set_linestyle('-')
    
    plt.tight_layout()
    plt.show()
    
    # 绘制第一组柱状图：缓存命中率
    plt.figure(figsize=(8, 8))  # 设置为正方形
    
    for i in range(num_cache_algs):
        plt.bar(x + i * width, results_hit_rate[i, :], width, 
                label=cache_names[i], color=cache_colors[i])
    
    plt.xlabel('任务类型数量 K', fontsize=22)
    plt.ylabel('缓存命中率 (%)', fontsize=22)
    # 去除标题
    plt.xticks(x + width * 2, k_values, fontsize=14)
    plt.yticks(fontsize=14)
    legend = plt.legend(loc='best', fontsize=14)
    legend.get_frame().set_edgecolor('black')
    legend.get_frame().set_linewidth(1.0)
    plt.grid(True, alpha=0.3)
    
    # 设置外边框为实线
    ax = plt.gca()
    for spine in ax.spines.values():
        spine.set_linewidth(1.0)
        spine.set_linestyle('-')
    
    plt.tight_layout()
    plt.show()
    
    # 绘制第一组柱状图：缓存命中任务总优先级
    plt.figure(figsize=(8, 8))  # 设置为正方形
    
    for i in range(num_cache_algs):
        plt.bar(x + i * width, results_hit_priority[i, :], width, 
                label=cache_names[i], color=cache_colors[i])
    
    plt.xlabel('任务类型数量 K', fontsize=22)
    plt.ylabel('缓存命中任务总优先级', fontsize=22)
    # 去除标题
    plt.xticks(x + width * 2, k_values, fontsize=14)
    plt.yticks(fontsize=14)
    legend = plt.legend(loc='best', fontsize=14)
    legend.get_frame().set_edgecolor('black')
    legend.get_frame().set_linewidth(1.0)
    plt.grid(True, alpha=0.3)
    
    # 设置外边框为实线
    ax = plt.gca()
    for spine in ax.spines.values():
        spine.set_linewidth(1.0)
        spine.set_linestyle('-')
    
    plt.tight_layout()
    plt.show()
    
    # 保存第一组数据（可选）
    # import pandas as pd
    # results_dict = {'K_Values': k_values}
    # for cache_idx in range(num_cache_algs):
    #     cache_suffix = cache_names[cache_idx].replace('缓存', '')
    #     results_dict[f'Revenue_{cache_suffix}'] = results_revenue[cache_idx, :]
    #     results_dict[f'Backlog_{cache_suffix}'] = results_backlog[cache_idx, :]
    #     results_dict[f'CacheValue_{cache_suffix}'] = results_cache_value[cache_idx, :]
    #     results_dict[f'HitRate_{cache_suffix}'] = results_hit_rate[cache_idx, :]
    #     results_dict[f'HitPriority_{cache_suffix}'] = results_hit_priority[cache_idx, :]
    # 
    # results_df = pd.DataFrame(results_dict)
    # filename = f'plot4_group1_k_cache_comparison_{pd.Timestamp.now().strftime("%Y%m%d_%H%M%S")}.csv'
    # results_df.to_csv(filename, index=False)
    # print(f'第一组结果已保存到文件: {filename}')


def plot_cache_strategies_vs_n():
    """第二组：
    横坐标取单时隙产生的不同任务数量 N= [10, 15, 20, 25, 30], 任务类型数量 K固定为 50
    纵坐标分别为（所有时隙的） MEC的时间平均收益（总收入/总时隙）、任务积压队列的平均长度（所有任务类型的总积压长度/总时隙）、MEC缓存的任务类型总价值，
    所有时隙的缓存命中率、所有时隙的所有任务缓存命中任务总优先级
    图例为：调度算法使用LyapunovSchedule + 五种不同的缓存更新算法（FIFO、LRU、LFU、Priority、Knapsack）"""
    
    # 导入必要的库
    import random
    import numpy as np
    
    # 实验参数设置
    n_values = [10, 15, 20, 25, 30]
    fixed_k = 50
    total_time_slots = 500
    Constants.total_cache_size(1000)
    num_runs = 5  # 多次实验取平均
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
    
    num_n = len(n_values)
    num_cache_algs = len(cache_algorithms)
    
    # 存储所有运行的结果
    all_runs_revenue = np.zeros((num_runs, num_cache_algs, num_n))
    all_runs_backlog = np.zeros((num_runs, num_cache_algs, num_n))
    all_runs_cache_value = np.zeros((num_runs, num_cache_algs, num_n))
    all_runs_hit_rate = np.zeros((num_runs, num_cache_algs, num_n))
    all_runs_hit_priority = np.zeros((num_runs, num_cache_algs, num_n))

    # 进行多次独立实验
    for run in range(num_runs):
        print(f'\n--- 第 {run + 1}/{num_runs} 次实验 ---')
        # 运行仿真实验
        for n_idx, current_n in enumerate(n_values):
            Constants.K(fixed_k)          # 设置任务类型数量
            Constants.N(current_n)        # 设置每时隙生成任务数
            
            print(f'  正在测试N={current_n} ({n_idx+1}/{num_n})...')
            
            for cache_idx, cache_alg in enumerate(cache_algorithms):
                cache_name = cache_names[cache_idx]
                
                # print(f'  缓存算法: {cache_name} ({cache_idx+1}/{num_cache_algs})') # 静默模式
                
                # 不同的实验运行使用不同的随机种子
                # 但在同一次运行中，所有算法和参数面对相同的环境和任务
                run_seed = 42 + run
                random.seed(run_seed)
                np.random.seed(run_seed)
                
                # 创建仿真器
                sim = Simulator(total_time_slots)
                
                # 设置调度策略为李雅普诺夫调度
                sim.set_schedule_strategy(Constants.LyapunovSchedule, Constants.VV_DEFAULT)
                
                # 设置缓存策略
                sim.set_cache_strategy(cache_alg)
                
                # 运行仿真（静默模式）
                try:
                    original_print = print
                    import builtins
                    builtins.print = lambda *args, **kwargs: None
                    
                    sim.run_simulation()
                    
                    builtins.print = original_print
                except Exception as e:
                    builtins.print = original_print
                    print(f'    仿真过程中出错: {e}')
                    continue
                
                # 获取统计结果
                stats = sim.get_statistics()
                all_runs_revenue[run, cache_idx, n_idx] = stats.AverageRevenue
                all_runs_backlog[run, cache_idx, n_idx] = stats.AverageBacklogQueueLength
                all_runs_cache_value[run, cache_idx, n_idx] = sim.MEC.get_cache_total_value(sim.TaskManager)
                if stats.TotalCacheAccess > 0:
                    all_runs_hit_rate[run, cache_idx, n_idx] = stats.CacheHitCount / stats.TotalCacheAccess * 100
                else:
                    all_runs_hit_rate[run, cache_idx, n_idx] = 0
                
                total_hit_priority = 0
                for task_type in stats.TaskTypeStats:
                    stat = stats.TaskTypeStats[task_type]
                    total_hit_priority += stat.CacheHitPrioritySum
                all_runs_hit_priority[run, cache_idx, n_idx] = total_hit_priority
    
    # 计算平均结果
    results_revenue = np.mean(all_runs_revenue, axis=0)
    results_backlog = np.mean(all_runs_backlog, axis=0)
    results_cache_value = np.mean(all_runs_cache_value, axis=0)
    results_hit_rate = np.mean(all_runs_hit_rate, axis=0)
    results_hit_priority = np.mean(all_runs_hit_priority, axis=0)
    print('\n=== 所有实验的平均结果计算完成 ===')
    
    # 绘制第二组柱状图：MEC时间平均收益
    plt.figure(figsize=(8, 8))  # 设置为正方形
    x = np.arange(len(n_values))
    width = 0.14  # 调整柱子宽度，增加间距
    
    # 定义缓存算法颜色方案（与第一组保持一致）
    cache_colors = ['#1f77b4', '#ff7f0e', '#ffbb78', '#9467bd', '#c5b0d5']
    
    for i in range(num_cache_algs):
        plt.bar(x + i * width, results_revenue[i, :], width, 
                label=cache_names[i], color=cache_colors[i])
    
    plt.xlabel('每时隙生成任务数量 N', fontsize=22)
    plt.ylabel('MEC时间平均收益', fontsize=22)
    # 去除标题
    plt.xticks(x + width * 2, n_values, fontsize=14)
    plt.yticks(fontsize=14)
    legend = plt.legend(loc='best', fontsize=14)
    legend.get_frame().set_edgecolor('black')
    legend.get_frame().set_linewidth(1.0)
    plt.grid(True, alpha=0.3)
    
    # 设置外边框为实线
    ax = plt.gca()
    for spine in ax.spines.values():
        spine.set_linewidth(1.0)
        spine.set_linestyle('-')
    
    plt.tight_layout()
    plt.show()
    
    # 绘制第二组柱状图：任务积压队列的平均长度
    plt.figure(figsize=(8, 8))  # 设置为正方形
    
    for i in range(num_cache_algs):
        plt.bar(x + i * width, results_backlog[i, :], width, 
                label=cache_names[i], color=cache_colors[i])
    
    plt.xlabel('每时隙生成任务数量 N', fontsize=22)
    plt.ylabel('任务积压队列的平均长度', fontsize=22)
    # 去除标题
    plt.xticks(x + width * 2, n_values, fontsize=14)
    plt.yticks(fontsize=14)
    legend = plt.legend(loc='best', fontsize=14)
    legend.get_frame().set_edgecolor('black')
    legend.get_frame().set_linewidth(1.0)
    plt.grid(True, alpha=0.3)
    
    # 设置外边框为实线
    ax = plt.gca()
    for spine in ax.spines.values():
        spine.set_linewidth(1.0)
        spine.set_linestyle('-')
    
    plt.tight_layout()
    plt.show()
    
    # 绘制第二组柱状图：MEC缓存的任务类型总价值
    plt.figure(figsize=(8, 8))  # 设置为正方形
    
    for i in range(num_cache_algs):
        plt.bar(x + i * width, results_cache_value[i, :], width, 
                label=cache_names[i], color=cache_colors[i])
    
    plt.xlabel('每时隙生成任务数量 N', fontsize=22)
    plt.ylabel('MEC缓存的任务类型总价值', fontsize=22)
    # 去除标题
    plt.xticks(x + width * 2, n_values, fontsize=14)
    plt.yticks(fontsize=14)
    legend = plt.legend(loc='best', fontsize=14)
    legend.get_frame().set_edgecolor('black')
    legend.get_frame().set_linewidth(1.0)
    plt.grid(True, alpha=0.3)
    
    # 设置外边框为实线
    ax = plt.gca()
    for spine in ax.spines.values():
        spine.set_linewidth(1.0)
        spine.set_linestyle('-')
    
    plt.tight_layout()
    plt.show()
    
    # 绘制第二组柱状图：缓存命中率
    plt.figure(figsize=(8, 8))  # 设置为正方形
    
    for i in range(num_cache_algs):
        plt.bar(x + i * width, results_hit_rate[i, :], width, 
                label=cache_names[i], color=cache_colors[i])
    
    plt.xlabel('每时隙生成任务数量 N', fontsize=22)
    plt.ylabel('缓存命中率 (%)', fontsize=22)
    # 去除标题
    plt.xticks(x + width * 2, n_values, fontsize=14)
    plt.yticks(fontsize=14)
    legend = plt.legend(loc='best', fontsize=14)
    legend.get_frame().set_edgecolor('black')
    legend.get_frame().set_linewidth(1.0)
    plt.grid(True, alpha=0.3)
    
    # 设置外边框为实线
    ax = plt.gca()
    for spine in ax.spines.values():
        spine.set_linewidth(1.0)
        spine.set_linestyle('-')
    
    plt.tight_layout()
    plt.show()
    
    # 绘制第二组柱状图：缓存命中任务总优先级
    plt.figure(figsize=(8, 8))  # 设置为正方形
    
    for i in range(num_cache_algs):
        plt.bar(x + i * width, results_hit_priority[i, :], width, 
                label=cache_names[i], color=cache_colors[i])
    
    plt.xlabel('每时隙生成任务数量 N', fontsize=22)
    plt.ylabel('缓存命中任务总优先级', fontsize=22)
    # 去除标题
    plt.xticks(x + width * 2, n_values, fontsize=14)
    plt.yticks(fontsize=14)
    legend = plt.legend(loc='best', fontsize=16)
    legend.get_frame().set_edgecolor('black')
    legend.get_frame().set_linewidth(1.0)
    plt.grid(True, alpha=0.3)
    
    # 设置外边框为实线
    ax = plt.gca()
    for spine in ax.spines.values():
        spine.set_linewidth(1.0)
        spine.set_linestyle('-')
    
    plt.tight_layout()
    plt.show()
    
    # 保存第二组数据（可选）
    # import pandas as pd
    # results_dict = {'N_Values': n_values}
    # for cache_idx in range(num_cache_algs):
    #     cache_suffix = cache_names[cache_idx].replace('缓存', '')
    #     results_dict[f'Revenue_{cache_suffix}'] = results_revenue[cache_idx, :]
    #     results_dict[f'Backlog_{cache_suffix}'] = results_backlog[cache_idx, :]
    #     results_dict[f'CacheValue_{cache_suffix}'] = results_cache_value[cache_idx, :]
    #     results_dict[f'HitRate_{cache_suffix}'] = results_hit_rate[cache_idx, :]
    #     results_dict[f'HitPriority_{cache_suffix}'] = results_hit_priority[cache_idx, :]
    # 
    # results_df = pd.DataFrame(results_dict)
    # filename = f'plot4_group2_n_cache_comparison_{pd.Timestamp.now().strftime("%Y%m%d_%H%M%S")}.csv'
    # results_df.to_csv(filename, index=False)
    # print(f'第二组结果已保存到文件: {filename}')


if __name__ == "__main__":
    plot4_cache_strategy_comparison()
