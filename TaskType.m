classdef TaskType < handle
    % TaskType 表示任务类型的静态信息
    
    properties
        Type        % 任务类型编号
        Priority    % 优先级
        Ck          % 计算复杂度
        MetaK       % 元数据量大小
        PK          % 产生概率
    end
    
    methods
        function obj = TaskType(type, priority, ck, metaK, pk)
            % 构造函数
            obj.Type = type;
            obj.Priority = priority;
            obj.Ck = ck;
            obj.MetaK = metaK;
            obj.PK = pk;
        end
    end
end
