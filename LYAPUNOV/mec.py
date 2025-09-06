"""
MEC多接入边缘计算节点类
"""

import random
import math

try:
    from .constants import Constants
    from .virtual_node import VirtualNode
    from .cache_classes import CacheEntry, AccessRecord
    from .task_classes import TaskValue
except ImportError:
    from constants import Constants
    from virtual_node import VirtualNode
    from cache_classes import CacheEntry, AccessRecord
    from task_classes import TaskValue


class MEC:
    """MEC 多接入边缘计算节点"""
    
    def __init__(self):
        """构造函数"""
        self.VirtualNodes = []              # 虚拟节点列表 (list)
        self.Cache = {}                     # 缓存映射，key为任务类型 (dict)
        self.UsedCacheSize = 0              # 已使用缓存大小 (Mbit)

        self.AccessCount = {}               # 每种任务类型的访问次数 (dict)
        self.AccessFrequency = {}           # 每种任务类型的访问频率 (dict)
        self.TotalTasksGenerated = 0        # 总生成任务数

        self.AccessRecords = {}             # 访问记录（用于LRU） (dict)
        self.CacheInsertOrder = []          # 缓存插入顺序（用于FIFO） (list)
        self.CurrentTimeSlot = 0            # 当前时隙

        self.CacheStrategy = Constants.Knapsack  # 缓存更新策略
        self.CacheEnabled = True            # 是否启用缓存功能

        self.Revenue = 0                    # 收益 (收入-代价)
        self.Income = 0                     # 收入
        self.Cost = 0                       # 代价
        
        # 初始化虚拟节点
        for i in range(Constants.V):
            frequency = random.randint(Constants.FMIN, Constants.FMAX)  # 随机计算频率
            self.VirtualNodes.append(VirtualNode(i + 1, frequency))
        
        # 初始化访问计数和频率
        K = Constants.K()
        for i in range(1, K + 1):
            self.AccessCount[i] = 0
            self.AccessFrequency[i] = 0.0
            self.AccessRecords[i] = AccessRecord(i, 0)
        
    def record_task_access(self, task_type):
        """记录任务访问（当生成任务时调用）"""
        self.AccessCount[task_type] = self.AccessCount[task_type] + 1
        self.TotalTasksGenerated += 1
        
        # 更新访问频率
        if self.TotalTasksGenerated > 0:
            self.AccessFrequency[task_type] = self.AccessCount[task_type] / self.TotalTasksGenerated
        
        # 更新访问记录（用于LRU）
        record = self.AccessRecords[task_type]
        record.LastAccessTime = self.CurrentTimeSlot
        record.AccessTimes.append(self.CurrentTimeSlot)
        
        # 保留最近40个时隙的访问记录
        LRU_WINDOW = 40
        if len(record.AccessTimes) > LRU_WINDOW:
            record.AccessTimes = record.AccessTimes[-LRU_WINDOW:]
        
    def is_cache_hit(self, task_type):
        """检查任务类型是否缓存命中"""
        # 如果缓存被禁用，总是返回false
        if not self.CacheEnabled:
            return False
        
        if task_type in self.Cache:
            entry = self.Cache[task_type]
            entry.HitCount += 1
            entry.LastAccessed = self.CurrentTimeSlot
            return True
        else:
            return False
        
    def is_task_type_computing(self, task_type):
        """检查指定任务类型是否正在计算中"""
        for node in self.VirtualNodes:
            if not node.IsIdle and node.CurrentTaskType == task_type:
                return True
        return False
        
    def get_idle_nodes(self):
        """获取空闲的虚拟节点"""
        idle_nodes = []
        for node in self.VirtualNodes:
            if node.IsIdle:
                idle_nodes.append(node)
        return idle_nodes
        
    def schedule_task(self, task_type, node_id, mkr, ck):
        """将任务调度到指定虚拟节点"""
        if node_id < 1 or node_id > Constants.V:
            return False
        
        node = self.VirtualNodes[node_id - 1]  # 转换为0基索引
        if not node.IsIdle:
            return False
        
        # 计算需要的时隙数
        required_slots = self._calculate_required_slots(mkr, ck, node.ComputeFrequency)
        
        # 调度任务
        node.IsIdle = False
        node.CurrentTaskType = task_type
        node.RemainingSlots = required_slots
        
        return True
        
    def update_nodes(self):
        """
        更新所有虚拟节点状态（每个时隙调用）
        返回一个dict, key=taskType, value=count
        """
        completed_task_types_map = {}
        
        for node in self.VirtualNodes:
            if not node.IsIdle:
                node.RemainingSlots -= 1
                if node.RemainingSlots <= 0:
                    # 任务计算完成
                    task_type = node.CurrentTaskType
                    if task_type in completed_task_types_map:
                        completed_task_types_map[task_type] += 1
                    else:
                        completed_task_types_map[task_type] = 1

                    node.IsIdle = True
                    node.CurrentTaskType = -1
                    node.RemainingSlots = 0
        
        return completed_task_types_map
        
    def set_cache_strategy(self, strategy):
        """设置缓存策略"""
        self.CacheStrategy = strategy
        
    def set_cache_enabled(self, enabled):
        """设置是否启用缓存"""
        self.CacheEnabled = enabled
        
    def update_time_slot(self, time_slot):
        """更新当前时隙"""
        self.CurrentTimeSlot = time_slot
        
    def update_revenue(self, task_manager, scheduled_tasks, completed_tasks, cache_hit_tasks):
        """
        更新收益并记录详细日志
        
        收益计算方式：
        1. 计算收入 = 任务完成收入 + 缓存命中收入
        2. 成本 = 缓存存储成本 + 计算能耗成本  
        3. 利润 = 收入 - 成本
        
        参数:
        scheduled_tasks: dict[taskType] -> {node, mkr, ck, backlogCount}
        completed_tasks: dict[taskType] -> backlogCount
        cache_hit_tasks: dict[taskType] -> {backlogCount, metaK}
        """
        # 导入日志工具
        try:
            from .logger import logger
        except ImportError:
            from logger import logger

        # 分类统计各项收入和成本
        cache_income = 0      # 缓存命中收入
        compute_income = 0    # 计算完成收入
        cache_cost = 0        # 缓存存储成本
        compute_cost = 0      # 计算能耗成本

        # --- 1. 计算任务完成的收入 ---
        for task_type, backlog_count in completed_tasks.items():
            if task_type in task_manager.TaskTypes:
                tt = task_manager.TaskTypes[task_type]
                income = Constants.WCOM * tt.Priority * backlog_count
                compute_income += income

        # --- 2. 计算缓存命中的收入和成本 ---
        for task_type, hit_info in cache_hit_tasks.items():
            if task_type in task_manager.TaskTypes:
                tt = task_manager.TaskTypes[task_type]
                # 缓存命中收入
                income = Constants.WHIT * tt.Priority * hit_info['backlogCount']
                cache_income += income
                # 缓存存储成本 (每个命中的任务类型只计算一次元数据成本)
                cost = Constants.BETA * tt.MetaK
                cache_cost += cost
            
        # --- 3. 计算新调度任务的能耗成本 ---
        for task_type, task_info in scheduled_tasks.items():
            node = task_info['node']
            frequency_ghz = node.ComputeFrequency / 1000.0
            required_slots = self._calculate_required_slots(task_info['mkr'], task_info['ck'], node.ComputeFrequency)
            cost = Constants.AFIE * (frequency_ghz ** 3) * Constants.NMT * required_slots
            compute_cost += cost

        # --- 4. 计算总收入、成本和利润 ---
        total_income = cache_income + compute_income
        total_cost = cache_cost + compute_cost
        current_profit = total_income - total_cost

        # --- 5. 更新累计值 ---
        self.Income += total_income
        self.Cost += total_cost
        self.Revenue = self.Income - self.Cost

        # --- 6. 记录详细日志 ---
        logger.log_revenue_details(
            self.CurrentTimeSlot,
            cache_income,
            compute_income, 
            cache_cost,
            compute_cost,
            current_profit
        )
        
    def get_cache_utilization(self):
        """获取缓存利用率"""
        return self.UsedCacheSize / Constants.total_cache_size()
        
    def get_node_utilization(self):
        """获取节点利用率"""
        busy_nodes = 0
        for node in self.VirtualNodes:
            if not node.IsIdle:
                busy_nodes += 1
        return busy_nodes / len(self.VirtualNodes)
        
    # 从MECCache.m移入的方法----------------------------------------
    def add_to_cache(self, task_type, meta_size, task_manager):
        """将任务类型添加到缓存"""
        # 检查是否已经缓存
        if task_type in self.Cache:
            return True
        
        # 检查缓存空间是否足够
        if self.UsedCacheSize + meta_size <= Constants.total_cache_size():
            # 直接添加到缓存
            entry = CacheEntry(task_type, meta_size, self.CurrentTimeSlot, self.CurrentTimeSlot)
            self.Cache[task_type] = entry
            self.UsedCacheSize += meta_size
            self.CacheInsertOrder.append(task_type)
            return True
        
        # 缓存空间不足，使用缓存替换策略
        return self.apply_cache_replacement_strategy(task_type, meta_size, task_manager)
        
    def apply_cache_replacement_strategy(self, new_task_type, new_meta_size, task_manager):
        """应用缓存替换策略"""
        if self.CacheStrategy == Constants.FIFO:
            return self.apply_fifo(new_task_type, new_meta_size)
        elif self.CacheStrategy == Constants.LFU:
            return self.apply_lfu(new_task_type, new_meta_size, task_manager)
        elif self.CacheStrategy == Constants.LRU:
            return self.apply_lru(new_task_type, new_meta_size, task_manager)
        elif self.CacheStrategy == Constants.Priority:
            return self.apply_priority(new_task_type, new_meta_size, task_manager)
        elif self.CacheStrategy == Constants.Knapsack:
            return self.apply_knapsack(new_task_type, new_meta_size, task_manager)
        else:
            return self.apply_fifo(new_task_type, new_meta_size)
        
    def apply_fifo(self, new_task_type, new_meta_size):
        """FIFO缓存替换策略"""
        while len(self.CacheInsertOrder) > 0:
            oldest_task_type = self.CacheInsertOrder.pop(0)
            
            if oldest_task_type in self.Cache:
                entry = self.Cache[oldest_task_type]
                self.UsedCacheSize -= entry.MetaSize
                del self.Cache[oldest_task_type]
                
                # 检查空间是否足够
                if self.UsedCacheSize + new_meta_size <= Constants.total_cache_size():
                    entry = CacheEntry(new_task_type, new_meta_size, self.CurrentTimeSlot, self.CurrentTimeSlot)
                    self.Cache[new_task_type] = entry
                    self.UsedCacheSize += new_meta_size
                    self.CacheInsertOrder.append(new_task_type)
                    return True
        return False
        
    def apply_lfu(self, new_task_type, new_meta_size, task_manager):
        """LFU (Least Frequently Used) 缓存替换策略"""
        # 找到命中次数最少的任务类型
        min_hit_count = float('inf')
        least_used_task_type = -1
        
        for task_type, entry in self.Cache.items():
            if entry.HitCount < min_hit_count:
                min_hit_count = entry.HitCount
                least_used_task_type = task_type
        
        if least_used_task_type != -1:
            entry = self.Cache[least_used_task_type]
            self.UsedCacheSize -= entry.MetaSize
            del self.Cache[least_used_task_type]
            
            # 递归尝试添加新任务
            return self.add_to_cache(new_task_type, new_meta_size, task_manager)
        else:
            return False
        
    def apply_lru(self, new_task_type, new_meta_size, task_manager):
        """LRU (Least Recently Used) 缓存替换策略（基于最近40个时隙）"""
        # 计算每个缓存任务类型在最近40个时隙的访问频率
        least_recent_access_time = float('inf')
        least_recent_task_type = -1
        
        for task_type in self.Cache:
            record = self.AccessRecords[task_type]
            
            if record.LastAccessTime < least_recent_access_time:
                least_recent_access_time = record.LastAccessTime
                least_recent_task_type = task_type
        
        if least_recent_task_type != -1:
            entry = self.Cache[least_recent_task_type]
            self.UsedCacheSize -= entry.MetaSize
            del self.Cache[least_recent_task_type]
            
            # 从插入顺序中移除
            if least_recent_task_type in self.CacheInsertOrder:
                self.CacheInsertOrder.remove(least_recent_task_type)
            
            # 递归尝试添加新任务
            return self.add_to_cache(new_task_type, new_meta_size, task_manager)
        else:
            return False
        
    def apply_priority(self, new_task_type, new_meta_size, task_manager):
        """基于优先级的缓存替换策略"""
        # 找到优先级最低的任务类型
        min_priority = float('inf')
        lowest_priority_task_type = -1
        
        for task_type in self.Cache:
            if task_type in task_manager.TaskTypes:
                tt = task_manager.TaskTypes[task_type]
                if tt.Priority < min_priority:
                    min_priority = tt.Priority
                    lowest_priority_task_type = task_type
        
        # 检查新任务的优先级是否更高
        if new_task_type in task_manager.TaskTypes:
            new_tt = task_manager.TaskTypes[new_task_type]
            if new_tt.Priority > min_priority and lowest_priority_task_type != -1:
                entry = self.Cache[lowest_priority_task_type]
                self.UsedCacheSize -= entry.MetaSize
                del self.Cache[lowest_priority_task_type]
                
                # 递归尝试添加新任务
                return self.add_to_cache(new_task_type, new_meta_size, task_manager)
            else:
                return False
        else:
            return False
        
    def apply_knapsack(self, new_task_type, new_meta_size, task_manager):
        """基于01背包算法的缓存替换策略"""
        # 构建候选任务列表（包括当前缓存中的任务和新任务）
        candidates = []
        
        # 添加当前缓存中的任务
        for task_type in self.Cache:
            if task_type in task_manager.TaskTypes:
                tt = task_manager.TaskTypes[task_type]
                value = self.AccessFrequency[task_type] * tt.Priority
                candidates.append(TaskValue(task_type, value, tt.MetaK))
        
        # 添加新任务
        if new_task_type in task_manager.TaskTypes:
            new_tt = task_manager.TaskTypes[new_task_type]
            new_value = self.AccessFrequency[new_task_type] * new_tt.Priority
            candidates.append(TaskValue(new_task_type, new_value, new_meta_size))
        
        # 使用01背包算法选择最优组合
        selected_tasks = self.solve_knapsack(candidates, Constants.total_cache_size())
        
        # 检查新任务是否被选中
        new_task_selected = False
        for task in selected_tasks:
            if task.TaskType == new_task_type:
                new_task_selected = True
                break
        
        if new_task_selected:
            # 清空当前缓存
            self.Cache = {}
            self.CacheInsertOrder = []
            self.UsedCacheSize = 0
            
            # 添加选中的任务到缓存
            for task in selected_tasks:
                entry = CacheEntry(task.TaskType, task.Weight, self.CurrentTimeSlot, self.CurrentTimeSlot)
                self.Cache[task.TaskType] = entry
                self.UsedCacheSize += task.Weight
                self.CacheInsertOrder.append(task.TaskType)
            
            return True
        else:
            return False
        
    def solve_knapsack(self, items, capacity):
        """01背包算法求解"""
        n = len(items)
        if n == 0:
            return []
        
        # 将容量转换为整数以便动态规划
        int_capacity = int(capacity)
        
        # dp[i][w] 表示前i个物品在容量为w时的最大价值
        dp = [[0 for _ in range(int_capacity + 1)] for _ in range(n + 1)]
        
        # 填充动态规划表
        for i in range(1, n + 1):
            for w in range(int_capacity + 1):
                item = items[i - 1]
                item_weight = int(item.Weight)
                
                if item_weight <= w:
                    # 可以选择当前物品
                    take_value = dp[i - 1][w - item_weight] + item.Value
                    not_take_value = dp[i - 1][w]
                    dp[i][w] = max(take_value, not_take_value)
                else:
                    # 不能选择当前物品
                    dp[i][w] = dp[i - 1][w]
        
        # 回溯找出选中的物品
        selected_tasks = []
        w = int_capacity
        for i in range(n, 0, -1):
            if dp[i][w] != dp[i - 1][w]:
                selected_tasks.append(items[i - 1])
                w -= int(items[i - 1].Weight)
        
        return selected_tasks
        
    def get_cache_total_value(self, task_manager):
        """
        获取当前缓存中所有任务类型的总价值
        价值 = 访问频率 * 优先级
        """
        total_value = 0
        
        for task_type in self.Cache:
            if task_type in task_manager.TaskTypes:
                tt = task_manager.TaskTypes[task_type]
                value = self.AccessFrequency[task_type] * tt.Priority
                total_value += value
        
        return total_value
    
    @staticmethod
    def _calculate_wkr(mkr, ck):
        """计算wkr(t) - 虚拟节点以最小计算频率计算任务所占用的时隙数量"""
        return math.ceil((mkr * ck / Constants.FM) / Constants.Tslot)
    
    @staticmethod
    def _calculate_required_slots(mkr,ck,freq):
        """计算所需时隙数量"""
        return math.ceil((mkr * ck / freq) / Constants.Tslot)
