"""
系统常量定义类
"""

class Constants:
    """系统常量定义类"""
    
    # 虚拟节点相关常量
    V = 10      # 虚拟节点数量
    FMIN = 500  # 最小计算频率 (MHz)
    FMAX = 2000 # 最大计算频率 (MHz)
    FM = 500    # 基准计算频率 (MHz)
    
    # 任务相关常量（调整后增加系统压力和复杂度）
    Tslot = 1   # 时隙长度 (秒)
    
    # 任务生成随机范围
    MIN_MKR = 4        # 最小输入数据量 (Mbit)
    MAX_MKR = 10       # 最大输入数据量 (Mbit)

    MIN_SKR = 6        # 最小时延预警值 (秒) 
    MAX_SKR = 10       # 最大时延预警值 (秒)

    MIN_CK = 1200      # 最小计算复杂度（提高计算需求）
    MAX_CK = 2000      # 最大计算复杂度

    MIN_METAK = 60     # 最小元数据量 (Mbit)
    MAX_METAK = 100    # 最大元数据量 (Mbit)

    MIN_PRIORITY = 1   # 最小优先级
    MAX_PRIORITY = 10   # 最大优先级
    
    # 收益计算参数
    WHIT = 1.0   # 缓存命中收入增益系数 
    WCOM = 0.2   # 任务计算收入增益系数 
    AFIE = 0.02  # MEC运行每焦耳的电价 
    NMT = 0.8    # MEC的能量系数 
    BETA = 0.1  # 缓存单bit数据的消耗系数 
    
    # 调度算法参数
    VV_DEFAULT = 4.0   # 默认李雅普诺夫漂移参数 
    
    # 缓存更新策略枚举
    FIFO = 1      # 先进先出
    LFU = 2       # 最少使用频率
    LRU = 3       # 最近最少使用
    Priority = 4  # 基于优先级
    Knapsack = 5  # 基于01背包算法
    
    GreedySchedule = 1     # 贪心调度（原有简单策略）
    ShortTermSchedule = 2  # 短期调度算法（调度算法2）[KM匹配策略]
    LyapunovSchedule = 3   # 李雅普诺夫调度算法（调度算法3，KM匹配）
    NoCacheSchedule = 4    # 无缓存调度算法（只用KM匹配，不考虑缓存）
    
    # 可变的全局参数（用于实验配置）
    _TOTAL_CACHE_SIZE_DEFAULT = 1000    # 总缓存大小 (Mbit)
    _K_DEFAULT = 40                     # 任务类型总数
    _N_DEFAULT = 80                     # 每个时隙产生的任务数量
    
    # 用于存储可变参数的类变量
    _total_cache_size = None
    _k = None
    _n = None
    
    @classmethod
    def total_cache_size(cls, new_size=None):
        """
        获取或设置总缓存大小
        用法:
        val = Constants.total_cache_size()      # 获取当前值
        Constants.total_cache_size(2000)        # 设置新值
        """
        if cls._total_cache_size is None:
            # 首次调用时，使用默认值初始化
            cls._total_cache_size = cls._TOTAL_CACHE_SIZE_DEFAULT
        
        if new_size is not None:
            # 如果提供了输入参数，则更新值 (setter)
            cls._total_cache_size = new_size
        
        # 返回当前值 (getter)
        return cls._total_cache_size
    
    @classmethod
    def K(cls, new_k=None):
        """
        获取或设置任务类型总数
        用法:
        val = Constants.K()      # 获取当前值
        Constants.K(25)          # 设置新值
        """
        if cls._k is None:
            cls._k = cls._K_DEFAULT
        
        if new_k is not None:
            cls._k = new_k
        
        return cls._k

    @classmethod
    def N(cls, new_n=None):
        """
        获取或设置每个时隙产生的任务数量
        用法:
        val = Constants.N()      # 获取当前值
        Constants.N(30)          # 设置新值
        """
        if cls._n is None:
            cls._n = cls._N_DEFAULT
        
        if new_n is not None:
            cls._n = new_n
        
        return cls._n
