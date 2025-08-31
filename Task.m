classdef Task < handle
    % Task 表示一个具体的任务实例
    
    properties
        ID          % 任务ID
        TaskType    % 任务类型 (1~K)
        Priority    % 任务优先级
        SKR         % 时延预警值 (秒)
        Age         % 任务当前年龄 (秒) 
        MKR         % 输入数据量大小 (Mbit)
        Ck          % 计算复杂度
        FKR         % 所需计算频率 (MHz)
        MetaK       % 元数据量大小 (Mbit)
        CreateTime  % 创建时隙
    end
    
    methods
        function obj = Task(id, taskType, priority, skr, mkr, ck, metaK, createTime)
            % 构造函数
            obj.ID = id;
            obj.TaskType = taskType;
            obj.Priority = priority;
            obj.SKR = skr;
            obj.Age = 0;
            obj.MKR = mkr;
            obj.Ck = ck;
            obj.FKR = ck * mkr; % 计算所需频率
            obj.MetaK = metaK;
            obj.CreateTime = createTime;
        end
    end
end