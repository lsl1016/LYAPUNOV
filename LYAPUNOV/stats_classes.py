"""
统计相关类
"""

try:
    from .constants import Constants
except ImportError:
    from constants import Constants


class TaskTypeStat:
    """TaskTypeStat 任务类型统计信息"""
    
    def __init__(self):
        """构造函数"""
        self.Generated = 0                  # 生成数量
        self.Completed = 0                  # 完成数量
        self.Dropped = 0                    # 丢弃数量
        self.CacheHits = 0                  # 缓存命中数量
        self.CacheHitPrioritySum = 0        # 缓存命中任务总优先级


class SimulationStats:
    """SimulationStats 仿真统计信息"""
    
    def __init__(self):
        """构造函数"""
        self.TotalTasksGenerated = 0        # 总生成任务数
        self.TotalTasksCompleted = 0        # 总完成任务数
        self.TotalTasksDropped = 0          # 总丢弃任务数
        
        self.CacheHitCount = 0              # 缓存命中次数
        self.TotalCacheAccess = 0           # 总缓存访问次数（统计最后所有时隙总的信息）
        
        self.TotalRevenue = 0               # 总收益
        self.AverageRevenue = 0             # 时间平均收益 （总收益/当前时隙数）

        self.TaskTypeStats = {}             # 各任务类型统计 (dict)
        
        # 时序数据记录（用于绘图）
        self.timeseries_data = {
            'time_slots': [],
            'cache_hit_rates': [],
            'completion_rates': [],
            'revenues': [],
            'cache_utilizations': [],
            'node_utilizations': []
        }
        
        # 初始化任务类型统计
        K = Constants.K()
        for i in range(1, K + 1):
            self.TaskTypeStats[i] = TaskTypeStat()
    
    def record_timeseries_data(self, time_slot, mec, task_manager):
        """记录时序数据用于绘图"""
        self.timeseries_data['time_slots'].append(time_slot)
        
        # 缓存命中率
        if self.TotalCacheAccess > 0:
            cache_hit_rate = self.CacheHitCount / self.TotalCacheAccess
        else:
            cache_hit_rate = 0
        self.timeseries_data['cache_hit_rates'].append(cache_hit_rate)
        
        # 任务完成率
        if self.TotalTasksGenerated > 0:
            completion_rate = self.TotalTasksCompleted / self.TotalTasksGenerated
        else:
            completion_rate = 0
        self.timeseries_data['completion_rates'].append(completion_rate)
        
        # 收益
        self.timeseries_data['revenues'].append(mec.Revenue)
        
        # 缓存利用率
        self.timeseries_data['cache_utilizations'].append(mec.get_cache_utilization())
        
        # 节点利用率
        self.timeseries_data['node_utilizations'].append(mec.get_node_utilization())
