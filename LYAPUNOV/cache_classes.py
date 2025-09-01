"""
缓存相关的类定义
从MATLAB版本转换而来，保留所有原始逻辑和注释
"""


class CacheEntry:
    """CacheEntry 缓存条目"""
    
    def __init__(self, task_type, meta_size, insert_time, last_accessed):
        """构造函数"""
        self.TaskType = task_type           # 任务类型
        self.MetaSize = meta_size          # 占用的元数据空间 (Mbit)
        self.HitCount = 0                  # 命中次数
        self.InsertTime = insert_time      # 插入时隙
        self.LastAccessed = last_accessed  # 最后访问时隙


class AccessRecord:
    """AccessRecord 访问记录"""
    
    def __init__(self, task_type, last_access_time):
        """构造函数"""
        self.TaskType = task_type          # 任务类型
        self.LastAccessTime = last_access_time  # 最后访问时隙
        self.AccessTimes = []              # 最近访问时隙列表（用于LRU）
