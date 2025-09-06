"""
虚拟节点类
"""

class VirtualNode:
    """VirtualNode 虚拟节点"""
    
    def __init__(self, node_id, compute_frequency):
        """构造函数"""
        self.ID = node_id                         # 节点ID
        self.ComputeFrequency = compute_frequency # 计算频率 (MHz)
        self.IsIdle = True                        # 是否空闲
        self.CurrentTaskType = -1                 # 当前计算的任务类型，-1表示无任务
        self.RemainingSlots = 0                   # 剩余计算时隙数
