"""
test_mec_system.py - MEC系统测试和示例程序
"""

from .constants import Constants
from .task_manager import TaskManager
from .mec import MEC
from .lyapunov_classes import LyapunovManager
from .scheduler import Scheduler
from .simulator import Simulator


def test_mec_system():
    """test_mec_system.py - MEC系统测试和示例程序"""
    
    print('=== MEC系统测试程序 ===\n')
    
    # 测试1: 基本组件测试
    print('1. 测试基本组件...')
    test_basic_components()
    
    # 测试2: 简单仿真测试
    print('2. 运行简单仿真测试...')
    test_simple_simulation()
    
    # 测试3: 缓存策略对比测试
    print('3. 测试不同缓存策略...')
    test_cache_strategies()
    
    print('\n=== 所有测试完成 ===')


def test_basic_components():
    """测试基本组件功能"""
    
    try:
        # 测试常量
        print('  - 测试常量定义... ', end='')
        assert Constants.V == 10, '虚拟节点数量错误'
        assert Constants.K() == 40, '任务类型数量错误'
        print('通过')
        
        # 测试任务管理器
        print('  - 测试任务管理器... ', end='')
        tm = TaskManager()
        assert len(tm.TaskTypes) > 0, '任务类型未初始化'
        assert len(tm.TaskTypes) == Constants.K(), '任务类型数量错误'
        task = tm.generate_task(1, 0)
        assert task is not None, '任务生成失败'
        assert task.TaskType == 1, '任务类型错误'
        print('通过')
        
        # 测试MEC节点
        print('  - 测试MEC节点... ', end='')
        mec = MEC()
        assert len(mec.VirtualNodes) == Constants.V, '虚拟节点数量错误'
        assert len(mec.Cache) == 0, '缓存应为空'
        print('通过')
        
        # 测试李雅普诺夫管理器
        print('  - 测试李雅普诺夫管理器... ', end='')
        lm = LyapunovManager()
        assert len(lm.Queues) == Constants.K(), '队列数量错误'
        assert lm.get_queue_length(1) == 0, '初始队列长度应为0'
        print('通过')
        
        # 测试调度器
        print('  - 测试调度器... ', end='')
        scheduler = Scheduler(Constants.GreedySchedule, Constants.VV_DEFAULT)
        assert scheduler.Algorithm == Constants.GreedySchedule, '调度算法错误'
        print('通过')
        
    except Exception as e:
        print(f'失败: {e}')
        raise e


def test_simple_simulation():
    """测试简单仿真"""
    
    try:
        print('  - 创建仿真器... ', end='')
        sim = Simulator(50)  # 运行50个时隙
        print('完成')
        
        print('  - 运行仿真... ', end='')
        sim.run_simulation()
        print('完成')
        
        # 检查统计结果
        stats = sim.get_statistics()
        assert stats.TotalTasksGenerated > 0, '应该生成了任务'
        
        print(f'  - 简单仿真测试完成，生成任务数: {stats.TotalTasksGenerated}，'
              f'完成任务数: {stats.TotalTasksCompleted}')
        
    except Exception as e:
        print(f'失败: {e}')
        raise e


def test_cache_strategies():
    """测试不同缓存策略"""
    
    time_slots = 100
    cache_strategies = [Constants.FIFO, Constants.LRU, Constants.Knapsack]
    strategy_names = ['FIFO', 'LRU', 'Knapsack']
    
    print(f'  - 测试缓存策略对比 (时隙数: {time_slots})')
    
    results = []
    
    for i, strategy in enumerate(cache_strategies):
        strategy_name = strategy_names[i]
        
        print(f'    测试 {strategy_name} 策略... ', end='')
        
        # 创建仿真器
        sim = Simulator(time_slots)
        sim.set_cache_strategy(strategy)
        sim.set_schedule_strategy(Constants.GreedySchedule)
        
        # 运行仿真（不输出详细信息）
        sim.MEC.update_time_slot(0)
        
        for t in range(time_slots):
            sim.CurrentTimeSlot = t
            sim.run_time_slot()
        
        # 收集结果
        stats = sim.get_statistics()
        result = {
            'strategy': strategy_name,
            'completion_rate': 0,
            'cache_hit_rate': 0,
            'revenue': sim.MEC.Revenue
        }
        
        if stats.TotalTasksGenerated > 0:
            result['completion_rate'] = stats.TotalTasksCompleted / stats.TotalTasksGenerated * 100
        
        if stats.TotalCacheAccess > 0:
            result['cache_hit_rate'] = stats.CacheHitCount / stats.TotalCacheAccess * 100
        
        results.append(result)
        
        print(f'完成率: {result["completion_rate"]:.1f}%, '
              f'命中率: {result["cache_hit_rate"]:.1f}%, '
              f'收益: {result["revenue"]:.2f}')
    
    # 找出最佳策略
    revenues = [r['revenue'] for r in results]
    best_idx = revenues.index(max(revenues))
    print(f'  - 最佳策略: {results[best_idx]["strategy"]} '
          f'(收益: {results[best_idx]["revenue"]:.2f})')


def quick_demo():
    """快速演示程序"""
    
    print('=== MEC系统快速演示 ===\n')
    
    # 创建一个简单的仿真
    print('创建仿真环境...')
    sim = Simulator(200)
    
    print('设置策略：李雅普诺夫调度 + 背包缓存')
    sim.set_schedule_strategy(Constants.LyapunovSchedule, Constants.VV_DEFAULT)
    sim.set_cache_strategy(Constants.Knapsack)
    
    print('开始仿真...\n')
    
    # 运行仿真
    sim.run_simulation()
    
    print('\n演示完成！')


if __name__ == '__main__':
    test_mec_system()
