"""
主程序文件 - MEC系统仿真
从MATLAB版本转换而来，保留所有原始逻辑和注释
"""

from .constants import Constants
from .simulator import Simulator


def main():
    """主程序入口 - 运行完整的策略比较仿真"""
    
    print("=== MEC系统仿真 - Python版本 ===")
    print("从MATLAB版本转换而来，保留所有原始逻辑\n")
    
    # 配置仿真参数
    time_slots = 1000
    strategies = [
        (Constants.GreedySchedule, "贪心调度"),
        (Constants.ShortTermSchedule, "短期调度"), 
        (Constants.LyapunovSchedule, "李雅普诺夫调度")
    ]
    cache_strategies = [
        (Constants.FIFO, "FIFO"),
        (Constants.LRU, "LRU"),
        (Constants.Knapsack, "背包算法")
    ]
    
    print(f"仿真配置:")
    print(f"  - 时隙数: {time_slots}")
    print(f"  - 虚拟节点数: {Constants.V}")
    print(f"  - 任务类型数: {Constants.K()}")
    print(f"  - 每时隙任务数: {Constants.N()}")
    print(f"  - 总缓存大小: {Constants.total_cache_size()} Mbit")
    print(f"  - 李雅普诺夫参数: {Constants.VV_DEFAULT}\n")
    
    results = []
    
    # 测试不同调度策略和缓存策略的组合
    for schedule_alg, schedule_name in strategies:
        for cache_alg, cache_name in cache_strategies:
            print(f"正在测试: {schedule_name} + {cache_name}")
            
            # 创建仿真器
            sim = Simulator(time_slots)
            sim.set_schedule_strategy(schedule_alg, Constants.VV_DEFAULT)
            sim.set_cache_strategy(cache_alg)
            
            # 运行仿真（静默模式）
            original_print = print
            def silent_print(*args, **kwargs):
                pass
            
            # 临时禁用打印输出
            import builtins
            builtins.print = silent_print
            
            try:
                sim.run_simulation()
            finally:
                # 恢复打印输出
                builtins.print = original_print
            
            # 收集结果
            stats = sim.get_statistics()
            result = {
                'schedule': schedule_name,
                'cache': cache_name,
                'completion_rate': stats.TotalTasksCompleted / stats.TotalTasksGenerated * 100 if stats.TotalTasksGenerated > 0 else 0,
                'cache_hit_rate': stats.CacheHitCount / stats.TotalCacheAccess * 100 if stats.TotalCacheAccess > 0 else 0,
                'revenue': sim.MEC.Revenue,
                'cache_utilization': sim.MEC.get_cache_utilization() * 100,
                'node_utilization': sim.MEC.get_node_utilization() * 100
            }
            results.append(result)
            
            print(f"  完成率: {result['completion_rate']:.1f}%, "
                  f"命中率: {result['cache_hit_rate']:.1f}%, "
                  f"收益: {result['revenue']:.2f}")
    
    # 输出最佳结果
    print(f"\n=== 策略比较结果 ===")
    print(f"{'调度策略':<12} {'缓存策略':<8} {'完成率':<8} {'命中率':<8} {'收益':<10} {'缓存利用':<8} {'节点利用':<8}")
    print("-" * 70)
    
    for result in results:
        print(f"{result['schedule']:<12} {result['cache']:<8} "
              f"{result['completion_rate']:<7.1f}% {result['cache_hit_rate']:<7.1f}% "
              f"{result['revenue']:<9.2f} {result['cache_utilization']:<7.1f}% "
              f"{result['node_utilization']:<7.1f}%")
    
    # 找出最佳策略
    best_result = max(results, key=lambda x: x['revenue'])
    print(f"\n最佳策略组合: {best_result['schedule']} + {best_result['cache']}")
    print(f"最高收益: {best_result['revenue']:.2f}")
    
    print(f"\n=== 仿真完成 ===")


def run_single_simulation():
    """运行单个仿真示例"""
    print("=== 单个仿真示例 ===")
    
    # 创建仿真器，使用推荐的策略组合
    sim = Simulator(500)
    sim.set_schedule_strategy(Constants.LyapunovSchedule, Constants.VV_DEFAULT)
    sim.set_cache_strategy(Constants.Knapsack)
    
    print("使用推荐策略: 李雅普诺夫调度 + 背包缓存")
    
    # 运行仿真
    sim.run_simulation()
    
    return sim


if __name__ == '__main__':
    # 可以选择运行完整比较或单个仿真
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == '--single':
        run_single_simulation()
    else:
        main()
