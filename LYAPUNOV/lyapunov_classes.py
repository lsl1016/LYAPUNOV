"""
李雅普诺夫队列相关类
"""

import math
try:
    from .constants import Constants
except ImportError:
    from constants import Constants
# 导入日志工具
try:
    from .logger import logger
except ImportError:
    from logger import logger


class LyapunovQueue:
    """LyapunovQueue 李雅普诺夫队列"""
    
    def __init__(self, task_type):
        """构造函数"""
        self.TaskType = task_type        # 任务类型
        self.QueueLength = 0            # 队列长度
        self.PreviousLength = 0         # 前一时隙的队列长度


class LyapunovManager:
    """LyapunovManager 李雅普诺夫队列管理器"""
    
    def __init__(self):
        """构造函数"""
        self.Queues = {}  # 每个任务类型对应一个队列 (dict)
        
        # 为每个任务类型初始化队列
        K = Constants.K()
        for i in range(1, K + 1):
            self.Queues[i] = LyapunovQueue(i)
    
    def update_queue(self, task_type, bk, dropped_count, ak, task_manager, scheduled_mkr=None, current_time_slot=None):
        """
        更新队列
        Qk(t+1) = max{Qk(t) - bk(t) - 当前类型丢弃的任务数量*wkr, 0} + ak(t)*wkr
        
        参数:
        bk: 本时隙完成的任务数
        dropped_count: 本时隙丢弃的任务数
        ak: 本时隙新到达的任务数
        scheduled_mkr: 实际调度的任务的mkr值（如果有的话）
        current_time_slot: 当前时隙（用于日志记录）
        """
     
        if task_type in self.Queues and task_type in task_manager.TaskTypes:
            q = self.Queues[task_type]
            tt = task_manager.TaskTypes[task_type]
            
            # 使用实际调度的任务的mkr值，如果没有则从积压队列中选择最容易满足时延约束的任务
            if scheduled_mkr is not None:
                mkr_to_use = scheduled_mkr
            else:
                # 从积压队列中选择所需计算频率最小的任务
                mkr_to_use = self._find_best_mkr_for_type(task_type, task_manager)
            
            wkr = self._calculate_wkr(mkr_to_use, tt.Ck)

            new_length = max(q.QueueLength - bk - dropped_count * wkr, 0) + ak * wkr
            
            q.QueueLength = new_length
            
            # 记录李雅普诺夫队列更新日志
            if current_time_slot is not None:
                logger.debug(f"时隙{current_time_slot}，更新李雅普诺夫队列，类型={task_type}，队列长度: {new_length:.2f}")
    
    def get_queue_length(self, task_type):
        """获取指定任务类型的队列长度"""
        if task_type in self.Queues:
            q = self.Queues[task_type]
            return q.QueueLength
        else:
            return 0
    
    def get_all_queue_lengths(self):
        """获取所有队列的长度"""
        K = Constants.K()
        lengths = [0] * (K + 1)  # 索引0不使用，从1开始
        for task_type in self.Queues:
            q = self.Queues[task_type]
            if 1 <= task_type <= K:
                lengths[task_type] = q.QueueLength
        return lengths[1:]  # 返回从索引1开始的部分

    def calculate_drift(self):
        """计算李雅普诺夫漂移"""
        drift = 0
        for task_type in self.Queues:
            q = self.Queues[task_type]
            drift += 0.5 * (q.QueueLength ** 2)
        return drift
    
    def _find_best_mkr_for_type(self, task_type, task_manager):
        """
        从指定类型的积压队列中选择所需计算频率最小的任务的mkr值
        这与李雅普诺夫调度算法中的选择逻辑一致
        """
        all_tasks_of_type = task_manager.get_backlog_tasks(task_type)
        if not all_tasks_of_type:
            # 如果没有积压任务，使用平均值
            return (Constants.MIN_MKR + Constants.MAX_MKR) / 2
        
        best_task = None
        min_required_freq = float('inf')
        
        for current_task in all_tasks_of_type:
            deadline_slots = current_task.SKR - current_task.Age
            if deadline_slots <= 0:
                continue
            required_freq = (current_task.Ck * current_task.MKR) / (deadline_slots * Constants.Tslot) / 1e6
            
            if required_freq < min_required_freq:
                min_required_freq = required_freq
                best_task = current_task
        
        if best_task is not None:
            return best_task.MKR
        else:
            # 如果所有任务都过期，使用平均值
            return (Constants.MIN_MKR + Constants.MAX_MKR) / 2

    @staticmethod
    def _calculate_wkr(mkr, ck):
        """计算wkr(t) - 虚拟节点以最小计算频率计算任务所占用的时隙数量"""
        return math.ceil((mkr * ck / Constants.FM) / Constants.Tslot)
