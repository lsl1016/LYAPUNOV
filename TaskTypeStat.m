classdef TaskTypeStat < handle
    % TaskTypeStat 任务类型统计信息
    
    properties
        Generated   % 生成数量
        Completed   % 完成数量
        Dropped     % 丢弃数量
        CacheHits   % 缓存命中数量
        CacheHitPrioritySum  % 缓存命中任务总优先级
    end
    
    methods
        function obj = TaskTypeStat()
            % 构造函数
            obj.Generated = 0;
            obj.Completed = 0;
            obj.Dropped = 0;
            obj.CacheHits = 0;
            obj.CacheHitPrioritySum = 0;
        end
    end
end
