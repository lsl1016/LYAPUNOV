"""
plot3_parameter_comparison.py - 不同参数下的性能对比柱状图

包含两组独立的柱状图：
第一组：不同任务类型数量K的性能对比（N=20, totalCacheSize=1000）
第二组：不同任务生成数量N的性能对比（K=40, totalCacheSize=1000）

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


def plot3_parameter_comparison():
    """参数对比实验"""
    print('=== 开始参数对比实验 ===')
    
    # 第一组实验：不同任务类型数量K的对比
    print('\n--- 第一组：不同任务类型数量K的对比 ---')
    plot_different_k_comparison()
    
    # 第二组实验：不同任务生成数量N的对比
    print('\n--- 第二组：不同任务生成数量N的对比 ---')
    plot_different_n_comparison()
    
    print('=== 参数对比实验完成 ===')


def plot_different_k_comparison():
    """第一组：
    横坐标取不同的任务类型 k= [40,50,60,70,80], 单时隙的产生任务数量 N=20，totalCacheSize(1000)
    纵坐标分别为（所有时隙的） MEC的时间平均收益（总收入/总时隙）、任务积压队列的平均长度（所有任务类型的总积压长度/总时隙）
    图例为：四种调度算法 + 缓存更新算法使用 Knapsack"""
    
    # 导入必要的库
    import random
    import numpy as np
    
    # 实验参数设置
    k_values = [40, 50, 60, 70, 80]
    fixed_n = 20                        # 固定N=20
    total_time_slots = 500              # 仿真时隙数
    Constants.total_cache_size(1000)    # 设置缓存大小为1000
    
    # 调度算法设置
    scheduling_algorithms = [
        Constants.GreedySchedule,
        Constants.ShortTermSchedule,
        Constants.LyapunovSchedule,
        Constants.NoCacheSchedule
    ]
    
    algorithm_names = [
        '贪心调度',
        '短期调度',
        '李雅普诺夫调度',
        '无缓存调度'
    ]
    
    num_k = len(k_values)
    num_algorithms = len(scheduling_algorithms)
    
    # 存储结果
    results_revenue = np.zeros((num_algorithms, num_k))
    results_backlog = np.zeros((num_algorithms, num_k))
    results_droprate = np.zeros((num_algorithms, num_k))
    
    # 运行仿真实验
    for k_idx, current_k in enumerate(k_values):
        Constants.K(current_k)        # 设置任务类型数量
        Constants.N(fixed_n)          # 设置每时隙生成任务数
        
        print(f'正在测试K={current_k} ({k_idx+1}/{num_k})...')
        
        for alg_idx, algorithm in enumerate(scheduling_algorithms):
            alg_name = algorithm_names[alg_idx]
            
            print(f'  调度算法: {alg_name} ({alg_idx+1}/{num_algorithms})')
            
            # 设置固定随机种子，确保所有算法面对相同的环境和任务
            import random
            random.seed(42)  # 所有算法使用相同的种子
            np.random.seed(42)
            
            # 创建仿真器
            sim = Simulator(total_time_slots)
            
            # 设置调度策略
            sim.set_schedule_strategy(algorithm, Constants.VV_DEFAULT)
            
            # 设置缓存策略（无缓存调度除外）
            if algorithm != Constants.NoCacheSchedule:
                sim.set_cache_strategy(Constants.Knapsack)
            else:
                sim.MEC.set_cache_enabled(False)
            
            # 运行仿真（静默模式）
            try:
                # 临时重定向输出
                original_print = print
                import builtins
                builtins.print = lambda *args, **kwargs: None
                
                sim.run_simulation()
                
                # 恢复print
                builtins.print = original_print
            except Exception as e:
                builtins.print = original_print
                print(f'    仿真过程中出错: {e}')
                continue
            
            # 获取统计结果
            stats = sim.get_statistics()
            results_revenue[alg_idx, k_idx] = stats.AverageRevenue
            results_backlog[alg_idx, k_idx] = stats.AverageBacklogQueueLength
            if stats.TotalTasksGenerated > 0:
                results_droprate[alg_idx, k_idx] = stats.TotalTasksDropped / stats.TotalTasksGenerated * 100
            else:
                results_droprate[alg_idx, k_idx] = 0
            
            print(f'    完成，平均收益: {results_revenue[alg_idx, k_idx]:.4f}, '
                  f'平均积压长度: {results_backlog[alg_idx, k_idx]:.2f}, '
                  f'丢弃率: {results_droprate[alg_idx, k_idx]:.2f}%')
    
    # 绘制第一组柱状图：MEC时间平均收益
    plt.figure(figsize=(8, 8))  # 设置为正方形
    x = np.arange(len(k_values))
    width = 0.18  # 调整柱子宽度，增加间距
    
    # 定义颜色方案（参考截图样式）
    colors = ['#1f77b4', '#ff7f0e', '#ffbb78', '#9467bd']
    
    for i in range(num_algorithms):
        plt.bar(x + i * width, results_revenue[i, :], width, 
                label=algorithm_names[i], color=colors[i])
    
    plt.xlabel('任务类型数量 K')
    plt.ylabel('MEC时间平均收益')
    # 去除标题
    plt.xticks(x + width * 1.5, k_values)
    plt.legend(loc='best')
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
    
    for i in range(num_algorithms):
        plt.bar(x + i * width, results_backlog[i, :], width, 
                label=algorithm_names[i], color=colors[i])
    
    plt.xlabel('任务类型数量 K')
    plt.ylabel('任务积压队列的平均长度')
    # 去除标题
    plt.xticks(x + width * 1.5, k_values)
    plt.legend(loc='best')
    plt.grid(True, alpha=0.3)
    
    # 设置外边框为实线
    ax = plt.gca()
    for spine in ax.spines.values():
        spine.set_linewidth(1.0)
        spine.set_linestyle('-')
    
    plt.tight_layout()
    plt.show()
    
    # 新增：绘制第三个图 - 任务丢弃率
    plt.figure(figsize=(8, 8))  # 设置为正方形
    
    for i in range(num_algorithms):
        plt.bar(x + i * width, results_droprate[i, :], width, 
                label=algorithm_names[i], color=colors[i])
    
    plt.xlabel('任务类型数量 K')
    plt.ylabel('任务丢弃率 (%)')
    # 去除标题
    plt.xticks(x + width * 1.5, k_values)
    plt.legend(loc='best')
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
    # for alg_idx in range(num_algorithms):
    #     clean_name = algorithm_names[alg_idx].replace('调度', '')
    #     results_dict[f'Revenue_{clean_name}'] = results_revenue[alg_idx, :]
    #     results_dict[f'Backlog_{clean_name}'] = results_backlog[alg_idx, :]
    # 
    # results_df = pd.DataFrame(results_dict)
    # filename = f'plot3_group1_k_comparison_{pd.Timestamp.now().strftime("%Y%m%d_%H%M%S")}.csv'
    # results_df.to_csv(filename, index=False)
    # print(f'第一组结果已保存到文件: {filename}')


def plot_different_n_comparison():
    """第二组：
    横坐标取单时隙产生的不同任务数量 N= [10,20,30,40,50], 任务类型数量 K固定为 40 ，totalCacheSize(1000)
    纵坐标分别为（所有时隙的） MEC的时间平均收益（总收入/总时隙）、任务积压队列的平均长度（所有任务类型的总积压长度/总时隙）
    图例为：四种调度算法 + 缓存更新算法使用 Knapsack"""
    
    # 实验参数设置
    n_values = [10, 20, 30, 40, 50]
    fixed_k = 40
    total_time_slots = 500
    Constants.total_cache_size(1000)
    
    # 调度算法设置
    scheduling_algorithms = [
        Constants.GreedySchedule,
        Constants.ShortTermSchedule,
        Constants.LyapunovSchedule,
        Constants.NoCacheSchedule
    ]
    
    algorithm_names = [
        '贪心调度',
        '短期调度',
        '李雅普诺夫调度',
        '无缓存调度'
    ]
    
    num_n = len(n_values)
    num_algorithms = len(scheduling_algorithms)
    
    # 存储结果
    results_revenue = np.zeros((num_algorithms, num_n))
    results_backlog = np.zeros((num_algorithms, num_n))
    results_droprate = np.zeros((num_algorithms, num_n))  # 新增：存储任务丢弃率
    
    # 运行仿真实验
    for n_idx, current_n in enumerate(n_values):
        Constants.K(fixed_k)          # 设置任务类型数量
        Constants.N(current_n)        # 设置每时隙生成任务数
        
        print(f'正在测试N={current_n} ({n_idx+1}/{num_n})...')
        
        for alg_idx, algorithm in enumerate(scheduling_algorithms):
            alg_name = algorithm_names[alg_idx]
            
            print(f'  调度算法: {alg_name} ({alg_idx+1}/{num_algorithms})')
            
            # 设置固定随机种子，确保所有算法面对相同的环境和任务
            import random
            random.seed(42)  # 所有算法使用相同的种子
            np.random.seed(42)
            
            # 创建仿真器
            sim = Simulator(total_time_slots)
            
            # 设置调度策略
            sim.set_schedule_strategy(algorithm, Constants.VV_DEFAULT)
            
            # 设置缓存策略（无缓存调度除外）
            if algorithm != Constants.NoCacheSchedule:
                sim.set_cache_strategy(Constants.Knapsack)
            else:
                sim.MEC.set_cache_enabled(False)
            
            # 运行仿真（静默模式）
            try:
                # 临时重定向输出
                original_print = print
                import builtins
                builtins.print = lambda *args, **kwargs: None
                
                sim.run_simulation()
                
                # 恢复print
                builtins.print = original_print
            except Exception as e:
                builtins.print = original_print
                print(f'    仿真过程中出错: {e}')
                continue
            
            # 获取统计结果
            stats = sim.get_statistics()
            results_revenue[alg_idx, n_idx] = stats.AverageRevenue
            results_backlog[alg_idx, n_idx] = stats.AverageBacklogQueueLength
            if stats.TotalTasksGenerated > 0:
                results_droprate[alg_idx, n_idx] = stats.TotalTasksDropped / stats.TotalTasksGenerated * 100
            else:
                results_droprate[alg_idx, n_idx] = 0
            
            print(f'    完成，平均收益: {results_revenue[alg_idx, n_idx]:.4f}, '
                  f'平均积压长度: {results_backlog[alg_idx, n_idx]:.2f}, '
                  f'丢弃率: {results_droprate[alg_idx, n_idx]:.2f}%')
    
    # 绘制第二组柱状图：MEC时间平均收益
    plt.figure(figsize=(8, 8))  # 设置为正方形
    x = np.arange(len(n_values))
    width = 0.18  # 调整柱子宽度，增加间距
    
    # 定义颜色方案（与第一组保持一致）
    colors = ['#1f77b4', '#ff7f0e', '#ffbb78', '#9467bd']
    
    for i in range(num_algorithms):
        plt.bar(x + i * width, results_revenue[i, :], width, 
                label=algorithm_names[i], color=colors[i])
    
    plt.xlabel('每时隙生成任务数量 N')
    plt.ylabel('MEC时间平均收益')
    # 去除标题
    plt.xticks(x + width * 1.5, n_values)
    plt.legend(loc='best')
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
    
    for i in range(num_algorithms):
        plt.bar(x + i * width, results_backlog[i, :], width, 
                label=algorithm_names[i], color=colors[i])
    
    plt.xlabel('每时隙生成任务数量 N')
    plt.ylabel('任务积压队列的平均长度')
    # 去除标题
    plt.xticks(x + width * 1.5, n_values)
    plt.legend(loc='best')
    plt.grid(True, alpha=0.3)
    
    # 设置外边框为实线
    ax = plt.gca()
    for spine in ax.spines.values():
        spine.set_linewidth(1.0)
        spine.set_linestyle('-')
    
    plt.tight_layout()
    plt.show()
    
    # 新增：绘制第三个图 - 任务丢弃率
    plt.figure(figsize=(8, 8))  # 设置为正方形
    
    for i in range(num_algorithms):
        plt.bar(x + i * width, results_droprate[i, :], width, 
                label=algorithm_names[i], color=colors[i])
    
    plt.xlabel('每时隙生成任务数量 N')
    plt.ylabel('任务丢弃率 (%)')
    # 去除标题
    plt.xticks(x + width * 1.5, n_values)
    plt.legend(loc='best')
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
    # for alg_idx in range(num_algorithms):
    #     clean_name = algorithm_names[alg_idx].replace('调度', '')
    #     results_dict[f'Revenue_{clean_name}'] = results_revenue[alg_idx, :]
    #     results_dict[f'Backlog_{clean_name}'] = results_backlog[alg_idx, :]
    # 
    # results_df = pd.DataFrame(results_dict)
    # filename = f'plot3_group2_n_comparison_{pd.Timestamp.now().strftime("%Y%m%d_%H%M%S")}.csv'
    # results_df.to_csv(filename, index=False)
    # print(f'第二组结果已保存到文件: {filename}')


if __name__ == "__main__":
    plot3_parameter_comparison()
