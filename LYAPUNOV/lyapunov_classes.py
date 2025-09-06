"""
李雅普诺夫队列相关类
"""

import math
try:
    from .constants import Constants
except ImportError:
    from constants import Constants


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
    
    def update_queue(self, task_type, bk, dropped_count, ak, task_manager):
        """
        更新队列
        Qk(t+1) = max{Qk(t) - bk(t) - 当前类型丢弃的任务数量*wkr, 0} + ak(t)*wkr
        
        参数:
        bk: 本时隙完成的任务数
        dropped_count: 本时隙丢弃的任务数
        ak: 本时隙新到达的任务数
        """
        if task_type in self.Queues and task_type in task_manager.TaskTypes:
            q = self.Queues[task_type]
            tt = task_manager.TaskTypes[task_type]
            
            # TODO: 这个mkr 应该是算出来的 
            # 从这个类型任务的积压队列中选择一个成功计算任务所需要计算频率最小的 freq，这个任务的mkr是真正的mkr
            # 所需要计算频率的计算方式为：mkr*ck / (skr - mkr的年龄)
            avg_mkr = (Constants.MIN_MKR + Constants.MAX_MKR) / 2
            wkr = self._calculate_wkr(avg_mkr, tt.Ck)

            new_length = max(q.QueueLength - bk - dropped_count * wkr, 0) + ak * wkr
            
            q.QueueLength = new_length
    
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
    
    @staticmethod
    def _calculate_wkr(mkr, ck):
        """计算wkr(t) - 虚拟节点以最小计算频率计算任务所占用的时隙数量"""
        return math.ceil((mkr * ck / Constants.FM) / Constants.Tslot)
