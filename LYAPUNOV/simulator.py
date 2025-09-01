"""
仿真器类
从MATLAB版本转换而来，保留所有原始逻辑和注释
"""

# 处理导入问题
try:
    from .constants import Constants
    from .mec import MEC
    from .task_manager import TaskManager
    from .lyapunov_classes import LyapunovManager
    from .scheduler import Scheduler
    from .stats_classes import SimulationStats
except ImportError:
    from constants import Constants
    from mec import MEC
    from task_manager import TaskManager
    from lyapunov_classes import LyapunovManager
    from scheduler import Scheduler
    from stats_classes import SimulationStats


class Simulator:
    """Simulator 仿真器"""
    
    def __init__(self, total_time_slots=1000):
        """构造函数"""
        self.MEC = MEC()
        self.TaskManager = TaskManager()
        self.LyapunovManager = LyapunovManager()
        self.Scheduler = Scheduler(Constants.GreedySchedule, Constants.VV_DEFAULT)  # 默认使用贪心调度
        self.CurrentTimeSlot = 0
        self.TotalTimeSlots = total_time_slots
        self.Statistics = SimulationStats()
        
    def set_cache_strategy(self, strategy):
        """设置缓存策略"""
        self.MEC.set_cache_strategy(strategy)
        
    def set_schedule_strategy(self, algorithm, vv=None):
        """设置调度策略 和 李雅普诺夫漂移参数"""
        if vv is None:
            vv = Constants.VV_DEFAULT
        self.Scheduler = Scheduler(algorithm, vv)
        
    def run_simulation(self):
        """运行仿真"""
        print(f'开始仿真，总时隙数: {self.TotalTimeSlots}')
        
        for t in range(self.TotalTimeSlots):
            self.CurrentTimeSlot = t
            self.run_time_slot()
            
            # 每100个时隙输出一次进度
            if (t + 1) % 100 == 0:
                print(f'时隙进度: {t + 1}/{self.TotalTimeSlots}')
        
        self.print_statistics()
        
    def run_time_slot(self):
        """运行单个时隙"""
        # 更新MEC的当前时隙
        self.MEC.update_time_slot(self.CurrentTimeSlot)
        
        # 用于当前时隙收益计算的数据
        scheduled_tasks = {}
        completed_tasks = {}
        cache_hit_tasks = {}

        # 1. 生成新任务并处理过期任务
        new_tasks = self.TaskManager.generate_random_tasks(self.CurrentTimeSlot)
        self.Statistics.TotalTasksGenerated += len(new_tasks)
        
        # 更新任务类型生成统计和访问统计
        for task in new_tasks:
            stat = self.Statistics.TaskTypeStats[task.TaskType]
            stat.Generated += 1
            # 记录任务访问（正确的访问统计方式）
            self.MEC.record_task_access(task.TaskType)
        
        # 移除过期任务
        expired_counts = self.TaskManager.remove_expired_tasks(self.CurrentTimeSlot)
        for task_type, count in expired_counts.items():
            self.Statistics.TotalTasksDropped += count
            stat = self.Statistics.TaskTypeStats[task_type]
            stat.Dropped += count
        
        # 2. 统一处理：先把所有新生成的任务都放到积压队列中
        for task in new_tasks:
            self.TaskManager.add_to_backlog(task)
            self.Statistics.TotalCacheAccess += 1
        
        # 3. 时隙开始检查：如果任务类型缓存命中，清空该类型积压队列
        K = Constants.K()
        for task_type in range(1, K + 1):
            backlog_count = self.TaskManager.get_backlog_count(task_type)
            if backlog_count > 0:
                if self.MEC.is_cache_hit(task_type):
                    # 缓存命中，该类型所有积压任务直接完成
                    self.Statistics.CacheHitCount += backlog_count
                    self.Statistics.TotalTasksCompleted += backlog_count
                    stat = self.Statistics.TaskTypeStats[task_type]
                    stat.CacheHits += backlog_count
                    stat.Completed += backlog_count
                    
                    # 记录缓存命中任务的总优先级
                    if task_type in self.TaskManager.TaskTypes:
                        tt = self.TaskManager.TaskTypes[task_type]
                        stat.CacheHitPrioritySum += (backlog_count * tt.Priority)
                        
                        # 记录用于收益计算
                        hit_info = {
                            'backlogCount': backlog_count,
                            'metaK': tt.MetaK
                        }
                        cache_hit_tasks[task_type] = hit_info
                    
                    self.TaskManager.remove_tasks_from_backlog(task_type, backlog_count)
        
        # 4. 调度积压队列中的任务
        scheduling_results = self.Scheduler.schedule_tasks(self.MEC, self.TaskManager, self.LyapunovManager)
        for res in scheduling_results:
            # 记录用于收益计算
            if res.TaskType in self.TaskManager.TaskTypes and res.NodeID > 0:
                tt = self.TaskManager.TaskTypes[res.TaskType]
                task_info = {
                    'node': self.MEC.VirtualNodes[res.NodeID - 1],  # 转换为0基索引
                    'mkr': res.MKR,
                    'ck': tt.Ck,
                    'backlogCount': res.CompletedTasks  # 假设调度一个任务就完成一个
                }
                scheduled_tasks[res.TaskType] = task_info
                  
        # 5. 更新虚拟节点状态
        completed_task_types_map = self.MEC.update_nodes()

        # 遍历所有类型积压队列，清空completedTaskTypes中存在的任务类型对应的积压队列
        # TotalTasksCompleted的统计应该等于对应的积压队列中的任务
        for task_type, _ in completed_task_types_map.items():
            backlog_count = self.TaskManager.get_backlog_count(task_type)
            
            if backlog_count > 0:
                self.Statistics.TotalTasksCompleted += backlog_count
                stat = self.Statistics.TaskTypeStats[task_type]
                stat.Completed += backlog_count
                
                # 记录用于收益计算
                completed_tasks[task_type] = backlog_count

                self.TaskManager.remove_tasks_from_backlog(task_type, backlog_count)
        
        # 更新任务类型完成统计 (这部分逻辑在上面处理积压队列时已完成)
        
        # 6. 缓存更新：完成的任务类型添加到缓存
        for task_type in completed_task_types_map:
            if task_type in self.TaskManager.TaskTypes:
                tt = self.TaskManager.TaskTypes[task_type]
                self.MEC.add_to_cache(task_type, tt.MetaK, self.TaskManager)
        
        # 7. 更新李雅普诺夫队列
        for task_type in range(1, K + 1):
            # 计算bk(t) - 本时隙完成的该类型任务数
            bk = 0
            for res in scheduling_results:
                if res.TaskType == task_type:
                    bk += res.CompletedTasks
            
            # 计算ak(t) - 本时隙新到达的该类型任务数
            ak = 0
            for task in new_tasks:
                if task.TaskType == task_type:
                    ak += 1
            
            # 计算丢弃的任务数
            dropped_count = 0
            if task_type in expired_counts:
                dropped_count = expired_counts[task_type]
            
            self.LyapunovManager.update_queue(task_type, bk, dropped_count, ak, self.TaskManager)
        
        # 8. 更新收益
        self.MEC.update_revenue(self.TaskManager, scheduled_tasks, completed_tasks, cache_hit_tasks)
        self.Statistics.TotalRevenue = self.MEC.Revenue  # 直接使用MEC累计的总收益
        
        # 更新平均收益
        if self.CurrentTimeSlot > 0:
            self.Statistics.AverageRevenue = self.Statistics.TotalRevenue / (self.CurrentTimeSlot + 1)
        else:
            self.Statistics.AverageRevenue = self.Statistics.TotalRevenue
        
        # 记录用于绘图的时序数据
        self.Statistics.record_timeseries_data(self.CurrentTimeSlot + 1, self.MEC, self.TaskManager, self.LyapunovManager)
        
    def print_statistics(self):
        """打印统计信息"""
        print('\n=== 仿真统计结果 ===')
        print(f'总时隙数: {self.TotalTimeSlots}')
        print(f'总生成任务数: {self.Statistics.TotalTasksGenerated}')
        print(f'总完成任务数: {self.Statistics.TotalTasksCompleted}')
        print(f'总丢弃任务数: {self.Statistics.TotalTasksDropped}')
        
        if self.Statistics.TotalTasksGenerated > 0:
            completion_rate = self.Statistics.TotalTasksCompleted / self.Statistics.TotalTasksGenerated * 100
            print(f'任务完成率: {completion_rate:.2f}%')
        else:
            print('任务完成率: 0.00%')
        
        print(f'缓存命中次数: {self.Statistics.CacheHitCount}')
        print(f'总缓存访问次数: {self.Statistics.TotalCacheAccess}')
        
        if self.Statistics.TotalCacheAccess > 0:
            cache_hit_rate = self.Statistics.CacheHitCount / self.Statistics.TotalCacheAccess * 100
            print(f'缓存命中率: {cache_hit_rate:.2f}%')
        else:
            print('缓存命中率: 0.00%')
        
        print(f'缓存利用率: {self.MEC.get_cache_utilization() * 100:.2f}%')
        print(f'节点利用率: {self.MEC.get_node_utilization() * 100:.2f}%')
        print(f'最终收益: {self.MEC.Revenue:.2f}')
        print(f'最终收入: {self.MEC.Income:.2f}')
        print(f'最终成本: {self.MEC.Cost:.2f}')
        
        # 计算平均队列长度
        total_lyapunov_queue_length = 0
        K = Constants.K()
        for i in range(1, K + 1):
            total_lyapunov_queue_length += self.LyapunovManager.get_queue_length(i)
        self.Statistics.AverageLyapunovQueueLength = total_lyapunov_queue_length / K
        print(f'平均队列长度: {self.Statistics.AverageLyapunovQueueLength:.2f}')
        
        # 积压队列平均长度（每个任务类型的平均积压长度）
        total_backlog_queue_length = 0
        for i in range(1, K + 1):
            total_backlog_queue_length += self.TaskManager.get_backlog_count(i)
        self.Statistics.AverageBacklogQueueLength = total_backlog_queue_length / K
        print(f'每个任务类型的平均积压队列长度: {self.Statistics.AverageBacklogQueueLength:.2f}')
        
        # 时间平均积压队列长度（用于绘图对比）
        if self.TotalTimeSlots > 0:
            time_avg_backlog = total_backlog_queue_length / self.TotalTimeSlots
            print(f'时间平均积压队列长度: {time_avg_backlog:.2f}')
        
        # 打印各任务类型统计
        print('\n=== 任务类型统计 ===')
        for task_type in self.Statistics.TaskTypeStats:
            stat = self.Statistics.TaskTypeStats[task_type]
            print(f'任务类型 {task_type}: 生成={stat.Generated}, 完成={stat.Completed}, '
                  f'丢弃={stat.Dropped}, 缓存命中={stat.CacheHits}')
        
    def get_statistics(self):
        """获取统计信息"""
        return self.Statistics
