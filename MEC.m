classdef mec < handle
    % MEC 多接入边缘计算节点
    
    properties
        VirtualNodes        % 虚拟节点列表 (cell array)
        Cache               % 缓存映射，key为任务类型 (containers.Map)
        UsedCacheSize       % 已使用缓存大小 (Mbit)
        Revenue             % 收益 (收入-代价)
        Income              % 收入
        Cost                % 代价

        AccessCount         % 每种任务类型的访问次数 (containers.Map)
        AccessFrequency     % 每种任务类型的访问频率 (containers.Map)
        TotalTasksGenerated % 总生成任务数

        AccessRecords       % 访问记录（用于LRU） (containers.Map)
        CacheInsertOrder    % 缓存插入顺序（用于FIFO） (array)
        CurrentTimeSlot     % 当前时隙


        CacheStrategy       % 缓存更新策略
        CacheEnabled        % 是否启用缓存功能
    end
    
    methods
        function obj = mec()
            % 构造函数
            obj.VirtualNodes = cell(1, constants.V);
            obj.Cache = containers.Map('KeyType', 'int32', 'ValueType', 'any');
            obj.UsedCacheSize = 0;
            obj.Revenue = 0;
            obj.Income = 0;
            obj.Cost = 0;
            obj.AccessCount = containers.Map('KeyType', 'int32', 'ValueType', 'int32');
            obj.AccessFrequency = containers.Map('KeyType', 'int32', 'ValueType', 'double');
            obj.TotalTasksGenerated = 0;
            obj.AccessRecords = containers.Map('KeyType', 'int32', 'ValueType', 'any');
            obj.CacheInsertOrder = [];
            obj.CurrentTimeSlot = 0;
            obj.CacheStrategy = constants.Knapsack; % 默认使用Knapsack策略
            obj.CacheEnabled = true; % 默认启用缓存
            
            % 初始化虚拟节点
            for i = 1:constants.V
                frequency = randi([Constants.FMIN, Constants.FMAX]); % 随机计算频率
                obj.VirtualNodes{i} = VirtualNode(i, frequency);
            end
            
            % 初始化访问计数和频率
            K = constants.getK();
            for i = 1:K
                obj.AccessCount(i) = 0;
                obj.AccessFrequency(i) = 0.0;
                obj.AccessRecords(i) = AccessRecord(i, 0);
            end
        end
        
        function recordTaskAccess(obj, taskType)
            % 记录任务访问（当生成任务时调用）
            obj.AccessCount(taskType) = obj.AccessCount(taskType) + 1;
            obj.TotalTasksGenerated = obj.TotalTasksGenerated + 1;
            
            % 更新访问频率
            if obj.TotalTasksGenerated > 0
                obj.AccessFrequency(taskType) = obj.AccessCount(taskType) / obj.TotalTasksGenerated;
            end
            
            % 更新访问记录（用于LRU）
            record = obj.AccessRecords(taskType);
            record.LastAccessTime = obj.CurrentTimeSlot;
            record.AccessTimes(end+1) = obj.CurrentTimeSlot;
            
            % 保留最近40个时隙的访问记录
            LRU_WINDOW = 40;
            if length(record.AccessTimes) > LRU_WINDOW
                record.AccessTimes = record.AccessTimes((end-LRU_WINDOW+1):end);
            end
        end
        
        function isHit = isCacheHit(obj, taskType)
            % 检查任务类型是否缓存命中
            % 如果缓存被禁用，总是返回false
            if ~obj.CacheEnabled
                isHit = false;
                return;
            end
            
            if obj.Cache.isKey(taskType)
                entry = obj.Cache(taskType);
                entry.HitCount = entry.HitCount + 1;
                entry.LastAccessed = obj.CurrentTimeSlot;
                isHit = true;
            else
                isHit = false;
            end
        end
        
        function isComputing = isTaskTypeComputing(obj, taskType)
            % 检查指定任务类型是否正在计算中
            isComputing = false;
            for i = 1:length(obj.VirtualNodes)
                node = obj.VirtualNodes{i};
                if ~node.IsIdle && node.CurrentTaskType == taskType
                    isComputing = true;
                    return;
                end
            end
        end
        
        function idleNodes = getIdleNodes(obj)
            % 获取空闲的虚拟节点
            idleNodes = {};
            for i = 1:length(obj.VirtualNodes)
                node = obj.VirtualNodes{i};
                if node.IsIdle
                    idleNodes{end+1} = node;
                end
            end
        end
        
        function success = scheduleTask(obj, taskType, nodeID, fkr)
            % 将任务调度到指定虚拟节点
            if nodeID < 1 || nodeID > constants.V
                success = false;
                return;
            end
            
            node = obj.VirtualNodes{nodeID};
            if ~node.IsIdle
                success = false;
                return;
            end
            
            % 计算需要的时隙数
            requiredSlots = TaskManager.calculateWKR(fkr);
            
            % 调度任务
            node.IsIdle = false;
            node.CurrentTaskType = taskType;
            node.RemainingSlots = requiredSlots;
            
            success = true;
        end
        
        function completedTaskTypes = updateNodes(obj)
            % 更新所有虚拟节点状态（每个时隙调用）
            completedTaskTypes = [];
            
            for i = 1:length(obj.VirtualNodes)
                node = obj.VirtualNodes{i};
                if ~node.IsIdle
                    node.RemainingSlots = node.RemainingSlots - 1;
                    if node.RemainingSlots <= 0
                        % 任务计算完成
                        completedTaskTypes(end+1) = node.CurrentTaskType;
                        node.IsIdle = true;
                        node.CurrentTaskType = -1;
                        node.RemainingSlots = 0;
                    end
                end
            end
        end
    end
end