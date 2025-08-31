classdef CacheEntry < handle
    % CacheEntry 缓存条目
    
    properties
        TaskType     % 任务类型
        MetaSize     % 占用的元数据空间 (Mbit)
        HitCount     % 命中次数
        InsertTime   % 插入时隙
        LastAccessed % 最后访问时隙
    end
    
    methods
        function obj = CacheEntry(taskType, metaSize, insertTime, lastAccessed)
            % 构造函数
            obj.TaskType = taskType;
            obj.MetaSize = metaSize;
            obj.HitCount = 0;
            obj.InsertTime = insertTime;
            obj.LastAccessed = lastAccessed;
        end
    end
end
