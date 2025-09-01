"""
任务相关的类定义
从MATLAB版本转换而来，保留所有原始逻辑和注释
"""

import random

# 处理导入问题
try:
    from .constants import Constants
except ImportError:
    from constants import Constants


class Task:
    """Task 表示一个具体的任务实例"""
    
    def __init__(self, task_id, task_type, priority, skr, mkr, ck, meta_k, create_time):
        """构造函数"""
        self.ID = task_id             # 任务ID
        self.TaskType = task_type     # 任务类型 (1~K)
        self.Priority = priority      # 任务优先级
        self.SKR = skr               # 时延预警值 (秒)
        self.Age = 0                 # 任务当前年龄 (秒) 
        self.MKR = mkr               # 输入数据量大小 (Mbit)
        self.Ck = ck                 # 计算复杂度
        self.FKR = ck * mkr          # 所需计算频率 (MHz)
        self.MetaK = meta_k          # 元数据量大小 (Mbit)
        self.CreateTime = create_time # 创建时隙


class TaskType:
    """TaskType 表示任务类型的静态信息"""
    
    def __init__(self, task_type, priority, ck, meta_k, pk):
        """构造函数"""
        self.Type = task_type        # 任务类型编号
        self.Priority = priority     # 优先级
        self.Ck = ck                # 计算复杂度
        self.MetaK = meta_k         # 元数据量大小
        self.PK = pk                # 产生概率


class TaskValue:
    """TaskValue 任务价值结构体（用于01背包算法）"""
    
    def __init__(self, task_type, value, weight):
        """构造函数"""
        self.TaskType = task_type    # 任务类型
        self.Value = value          # 价值
        self.Weight = weight        # 权重


class TaskValue2:
    """TaskValue2 任务价值结构体（用于调度）"""
    
    def __init__(self, task_type, priority, access_freq=0, backlog_count=0, lyapunov_queue=0):
        """构造函数"""
        self.TaskType = task_type           # 任务类型
        self.Priority = priority            # 优先级
        self.AccessFreq = access_freq       # 访问频率
        self.Value = access_freq * priority # 价值 (访问频率 * 优先级)
        self.BacklogCount = backlog_count   # 积压数量
        self.LyapunovQueue = lyapunov_queue # 李雅普诺夫队列长度


class SchedulingResult:
    """SchedulingResult 调度结果"""
    # [任务类型, 虚拟节点ID, 匹配代价, 因调度而完成的积压任务数量]
    
    def __init__(self, task_type=0, node_id=0, match_cost=0, completed_tasks=0):
        """构造函数"""
        self.TaskType = task_type           # 任务类型
        self.NodeID = node_id              # 分配的虚拟节点ID
        self.MatchCost = match_cost        # 匹配代价
        self.CompletedTasks = completed_tasks # 改为时间槽增益数
        self.MKR = 0                       # 输入数据量（用于调度结果记录）
