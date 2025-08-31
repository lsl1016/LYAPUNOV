classdef constants < handle
    % 系统常量定义类
    
    properties (Constant)
        % 虚拟节点相关常量
        V = 5;      % 虚拟节点数量
        FMIN = 2000; % 最小计算频率 (MHz)
        FMAX = 4000; % 最大计算频率 (MHz)
        FM = 1000;   % 基准计算频率 (MHz)
        
        % 任务相关常量（调整后增加系统压力和复杂度）
        Tslot = 1; % 时隙长度 (秒)
        
        % 任务生成随机范围
        MIN_MKR = 4;       % 最小输入数据量 (Mbit)
        MAX_MKR = 20;       % 最大输入数据量 (Mbit)

        MIN_SKR = 6;        % 最小时延预警值 (秒) - 更紧迫的截止时间
        MAX_SKR = 10;       % 最大时延预警值 (秒)

        MIN_CK = 500;       % 最小计算复杂度（提高计算需求）
        MAX_CK = 1500;      % 最大计算复杂度

        MIN_METAK = 60;    % 最小元数据量 (Mbit)（增加缓存价值）
        MAX_METAK = 100;    % 最大元数据量 (Mbit)

        MIN_PRIORITY = 1;   % 最小优先级
        MAX_PRIORITY = 5;   % 最大优先级
        
        % 收益计算参数
        WHIT = 3.0;  % 缓存命中收入增益系数 
        WCOM = 1.2;  % 任务计算收入增益系数 
        AFIE = 0.02; % MEC运行每焦耳的电价 
        NMT = 0.8;   % MEC的能量系数 
        BETA = 0.01; % 缓存单bit数据的消耗系数 
        
        % 调度算法参数
        VV_DEFAULT = 6.0; % 默认李雅普诺夫漂移参数 
        
        % 缓存更新策略枚举
        FIFO = 1;     % 先进先出
        LFU = 2;      % 最少使用频率
        LRU = 3;      % 最近最少使用
        Priority = 4; % 基于优先级
        Knapsack = 5; % 基于01背包算法
        
        GreedySchedule = 1;    % 贪心调度（原有简单策略）
        ShortTermSchedule = 2; % 短期调度算法（调度算法2）[KM匹配策略]
        LyapunovSchedule = 3;  % 李雅普诺夫调度算法（调度算法3，KM匹配）
        NoCacheSchedule = 4;   % 无缓存调度算法（只用KM匹配，不考虑缓存）
    end
    
    properties (Constant, Access = private)
        % 可变的全局参数（用于实验配置）
        TOTAL_CACHE_SIZE_DEFAULT = 1500.0; % 总缓存大小 (Mbit)
        K_DEFAULT = 40;                     % 任务类型总数
        N_DEFAULT = 25;                     % 每个时隙产生的任务数量（默认25）
    end
    
    methods (Static)
        function value = totalCacheSize(new_size)
            % 获取或设置总缓存大小
            % 用法:
            % val = constants.totalCacheSize();      % 获取当前值
            % constants.totalCacheSize(2000);        % 设置新值
            persistent current_size;
            
            if isempty(current_size)
                % 首次调用时，使用默认值初始化
                current_size = constants.TOTAL_CACHE_SIZE_DEFAULT;
            end
            
            if nargin > 0
                % 如果提供了输入参数，则更新值 (setter)
                current_size = new_size;
            end
            
            % 返回当前值 (getter)
            value = current_size;
        end
        
        function value = K(new_k)
            % 获取或设置任务类型总数
            % 用法:
            % val = constants.K();      % 获取当前值
            % constants.K(25);          % 设置新值
            persistent current_k;
            
            if isempty(current_k)
                current_k = constants.K_DEFAULT;
            end
            
            if nargin > 0
                current_k = new_k;
            end
            
            value = current_k;
        end

        function value = N(new_n)

            % 获取或设置每个时隙产生的任务数量
            % 用法:
            % val = constants.N();      % 获取当前值
            % constants.N(30);          % 设置新值
            persistent current_n;

            if isempty(current_n)
                current_n = constants.N_DEFAULT;
            end
            
            if nargin > 0
                current_n = new_n;
            end
            
            value = current_n;
        end

    end
end