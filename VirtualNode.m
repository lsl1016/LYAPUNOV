classdef VirtualNode < handle
    % VirtualNode 虚拟节点
    
    properties
        ID               % 节点ID
        ComputeFrequency % 计算频率 (MHz)
        IsIdle           % 是否空闲
        CurrentTaskType  % 当前计算的任务类型，-1表示无任务
        RemainingSlots   % 剩余计算时隙数
    end
    
    methods
        function obj = VirtualNode(id, computeFrequency)
            % 构造函数
            obj.ID = id;
            obj.ComputeFrequency = computeFrequency;
            obj.IsIdle = true;
            obj.CurrentTaskType = -1;
            obj.RemainingSlots = 0;
        end
    end
end
