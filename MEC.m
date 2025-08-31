classdef MEC < handle
    % MEC 多接入边缘计算节点
    
    properties
        VirtualNodes        % 虚拟节点列表 (cell array)
        Cache               % 缓存映射，key为任务类型 (containers.Map)
        UsedCacheSize       % 已使用缓存大小 (Mbit)

        AccessCount         % 每种任务类型的访问次数 (containers.Map)
        AccessFrequency     % 每种任务类型的访问频率 (containers.Map)
        TotalTasksGenerated % 总生成任务数

        AccessRecords       % 访问记录（用于LRU） (containers.Map)
        CacheInsertOrder    % 缓存插入顺序（用于FIFO） (array)
        CurrentTimeSlot     % 当前时隙

        CacheStrategy       % 缓存更新策略
        CacheEnabled        % 是否启用缓存功能

        Revenue             % 收益 (收入-代价)
        Income              % 收入
        Cost                % 代价
    end
    
    methods
        function obj = MEC()
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
                frequency = randi([constants.FMIN, constants.FMAX]); % 随机计算频率
                obj.VirtualNodes{i} = VirtualNode(i, frequency);
            end
            
            % 初始化访问计数和频率
            K = constants.K();
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
        
        function success = scheduleTask(obj, taskType, nodeID, mkr, ck)
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
            requiredSlots = TaskManager.calculateWKR(mkr, ck);
            
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
        
        function setCacheStrategy(obj, strategy)
            % 设置缓存策略
            obj.CacheStrategy = strategy;
        end
        
        function setCacheEnabled(obj, enabled)
            % 设置是否启用缓存
            obj.CacheEnabled = enabled;
        end
        
        function updateTimeSlot(obj, timeSlot)
            % 更新当前时隙
            obj.CurrentTimeSlot = timeSlot;
        end
        
        function updateRevenue(obj, taskManager)
            % 更新收益计算
            % 收入 = 缓存命中收益 + 计算收益
            % 成本 = 能耗成本 + 缓存存储成本
            
            % 计算缓存命中收益
            cacheHitRevenue = 0;
            keys = cell2mat(obj.Cache.keys);
            for i = 1:length(keys)
                entry = obj.Cache(keys(i));
                if taskManager.TaskTypes.isKey(keys(i))
                    tt = taskManager.TaskTypes(keys(i));
                    cacheHitRevenue = cacheHitRevenue + entry.HitCount * constants.WHIT * tt.Priority;
                end
            end
            
            % 计算计算收益
            computeRevenue = 0;
            for i = 1:length(obj.VirtualNodes)
                node = obj.VirtualNodes{i};
                if ~node.IsIdle
                    if taskManager.TaskTypes.isKey(node.CurrentTaskType)
                        tt = taskManager.TaskTypes(node.CurrentTaskType);
                        computeRevenue = computeRevenue + constants.WCOM * tt.Priority;
                    end
                end
            end
            
            % 计算能耗成本
            energyCost = 0;
            for i = 1:length(obj.VirtualNodes)
                node = obj.VirtualNodes{i};
                if ~node.IsIdle
                    frequencyGHz = node.ComputeFrequency / 1000.0;
                    energyCost = energyCost + constants.AFIE * (frequencyGHz^3) * constants.NMT * constants.Tslot;
                end
            end
            
            % 计算缓存存储成本
            cacheCost = obj.UsedCacheSize * constants.BETA;
            
            obj.Income = cacheHitRevenue + computeRevenue;
            obj.Cost = energyCost + cacheCost;
            obj.Revenue = obj.Income - obj.Cost;
        end
        
        function utilization = getCacheUtilization(obj)
            % 获取缓存利用率
            utilization = obj.UsedCacheSize / constants.totalCacheSize();
        end
        
        function utilization = getNodeUtilization(obj)
            % 获取节点利用率
            busyNodes = 0;
            for i = 1:length(obj.VirtualNodes)
                if ~obj.VirtualNodes{i}.IsIdle
                    busyNodes = busyNodes + 1;
                end
            end
            utilization = busyNodes / length(obj.VirtualNodes);
        end
        
        % 从MECCache.m移入的方法----------------------------------------
        function success = addToCache(obj, taskType, metaSize, taskManager)
            % 将任务类型添加到缓存
            % 检查是否已经缓存
            if obj.Cache.isKey(taskType)
                success = true;
                return;
            end
            
            % 检查缓存空间是否足够
            if obj.UsedCacheSize + metaSize <= constants.totalCacheSize()
                % 直接添加到缓存
                entry = CacheEntry(taskType, metaSize, obj.CurrentTimeSlot, obj.CurrentTimeSlot);
                obj.Cache(taskType) = entry;
                obj.UsedCacheSize = obj.UsedCacheSize + metaSize;
                obj.CacheInsertOrder(end+1) = taskType;
                success = true;
                return;
            end
            
            % 缓存空间不足，使用缓存替换策略
            success = obj.applyCacheReplacementStrategy(taskType, metaSize, taskManager);
        end
        
        function success = applyCacheReplacementStrategy(obj, newTaskType, newMetaSize, taskManager)
            % 应用缓存替换策略
            switch obj.CacheStrategy
                case constants.FIFO
                    success = obj.applyFIFO(newTaskType, newMetaSize);
                case constants.LFU
                    success = obj.applyLFU(newTaskType, newMetaSize, taskManager);
                case constants.LRU
                    success = obj.applyLRU(newTaskType, newMetaSize, taskManager);
                case constants.Priority
                    success = obj.applyPriority(newTaskType, newMetaSize, taskManager);
                case constants.Knapsack
                    success = obj.applyKnapsack(newTaskType, newMetaSize, taskManager);
                otherwise
                    success = obj.applyFIFO(newTaskType, newMetaSize);
            end
        end
        
        function success = applyFIFO(obj, newTaskType, newMetaSize)
            % FIFO缓存替换策略
            while ~isempty(obj.CacheInsertOrder)
                oldestTaskType = obj.CacheInsertOrder(1);
                obj.CacheInsertOrder(1) = [];
                
                if obj.Cache.isKey(oldestTaskType)
                    entry = obj.Cache(oldestTaskType);
                    obj.UsedCacheSize = obj.UsedCacheSize - entry.MetaSize;
                    obj.Cache.remove(oldestTaskType);
                    
                    % 检查空间是否足够
                    if obj.UsedCacheSize + newMetaSize <= constants.totalCacheSize()
                        entry = CacheEntry(newTaskType, newMetaSize, obj.CurrentTimeSlot, obj.CurrentTimeSlot);
                        obj.Cache(newTaskType) = entry;
                        obj.UsedCacheSize = obj.UsedCacheSize + newMetaSize;
                        obj.CacheInsertOrder(end+1) = newTaskType;
                        success = true;
                        return;
                    end
                end
            end
            success = false;
        end
        
        function success = applyLFU(obj, newTaskType, newMetaSize, taskManager)
            % LFU (Least Frequently Used) 缓存替换策略
            % 找到命中次数最少的任务类型
            minHitCount = inf;
            leastUsedTaskType = -1;
            
            keys = cell2mat(obj.Cache.keys);
            for i = 1:length(keys)
                entry = obj.Cache(keys(i));
                if entry.HitCount < minHitCount
                    minHitCount = entry.HitCount;
                    leastUsedTaskType = keys(i);
                end
            end
            
            if leastUsedTaskType ~= -1
                entry = obj.Cache(leastUsedTaskType);
                obj.UsedCacheSize = obj.UsedCacheSize - entry.MetaSize;
                obj.Cache.remove(leastUsedTaskType);
                
                % 递归尝试添加新任务
                success = obj.addToCache(newTaskType, newMetaSize, taskManager);
            else
                success = false;
            end
        end
        
        function success = applyLRU(obj, newTaskType, newMetaSize, taskManager)
            % LRU (Least Recently Used) 缓存替换策略（基于最近40个时隙）
            LRU_WINDOW = 40;
            
            % 计算每个缓存任务类型在最近40个时隙的访问频率
            leastRecentAccessTime = inf;
            leastRecentTaskType = -1;
            
            keys = cell2mat(obj.Cache.keys);
            for i = 1:length(keys)
                taskType = keys(i);
                record = obj.AccessRecords(taskType);
                
                if record.LastAccessTime < leastRecentAccessTime
                    leastRecentAccessTime = record.LastAccessTime;
                    leastRecentTaskType = taskType;
                end
            end
            
            if leastRecentTaskType ~= -1
                entry = obj.Cache(leastRecentTaskType);
                obj.UsedCacheSize = obj.UsedCacheSize - entry.MetaSize;
                obj.Cache.remove(leastRecentTaskType);
                
                % 从插入顺序中移除
                idx = find(obj.CacheInsertOrder == leastRecentTaskType, 1);
                if ~isempty(idx)
                    obj.CacheInsertOrder(idx) = [];
                end
                
                % 递归尝试添加新任务
                success = obj.addToCache(newTaskType, newMetaSize, taskManager);
            else
                success = false;
            end
        end
        
        function success = applyPriority(obj, newTaskType, newMetaSize, taskManager)
            % 基于优先级的缓存替换策略
            % 找到优先级最低的任务类型
            minPriority = inf;
            lowestPriorityTaskType = -1;
            
            keys = cell2mat(obj.Cache.keys);
            for i = 1:length(keys)
                taskType = keys(i);
                if taskManager.TaskTypes.isKey(taskType)
                    tt = taskManager.TaskTypes(taskType);
                    if tt.Priority < minPriority
                        minPriority = tt.Priority;
                        lowestPriorityTaskType = taskType;
                    end
                end
            end
            
            % 检查新任务的优先级是否更高
            if taskManager.TaskTypes.isKey(newTaskType)
                newTT = taskManager.TaskTypes(newTaskType);
                if newTT.Priority > minPriority && lowestPriorityTaskType ~= -1
                    entry = obj.Cache(lowestPriorityTaskType);
                    obj.UsedCacheSize = obj.UsedCacheSize - entry.MetaSize;
                    obj.Cache.remove(lowestPriorityTaskType);
                    
                    % 递归尝试添加新任务
                    success = obj.addToCache(newTaskType, newMetaSize, taskManager);
                else
                    success = false;
                end
            else
                success = false;
            end
        end
        
        function success = applyKnapsack(obj, newTaskType, newMetaSize, taskManager)
            % 基于01背包算法的缓存替换策略
            % 构建候选任务列表（包括当前缓存中的任务和新任务）
            candidates = {};
            
            % 添加当前缓存中的任务
            keys = cell2mat(obj.Cache.keys);
            for i = 1:length(keys)
                taskType = keys(i);
                if taskManager.TaskTypes.isKey(taskType)
                    tt = taskManager.TaskTypes(taskType);
                    value = obj.AccessFrequency(taskType) * tt.Priority;
                    candidates{end+1} = TaskValue(taskType, value, tt.MetaK);
                end
            end
            
            % 添加新任务
            if taskManager.TaskTypes.isKey(newTaskType)
                newTT = taskManager.TaskTypes(newTaskType);
                newValue = obj.AccessFrequency(newTaskType) * newTT.Priority;
                candidates{end+1} = TaskValue(newTaskType, newValue, newMetaSize);
            end
            
            % 使用01背包算法选择最优组合
            selectedTasks = obj.solveKnapsack(candidates, constants.totalCacheSize());
            
            % 检查新任务是否被选中
            newTaskSelected = false;
            for i = 1:length(selectedTasks)
                if selectedTasks{i}.TaskType == newTaskType
                    newTaskSelected = true;
                    break;
                end
            end
            
            if newTaskSelected
                % 清空当前缓存
                obj.Cache = containers.Map('KeyType', 'int32', 'ValueType', 'any');
                obj.CacheInsertOrder = [];
                obj.UsedCacheSize = 0;
                
                % 添加选中的任务到缓存
                for i = 1:length(selectedTasks)
                    task = selectedTasks{i};
                    entry = CacheEntry(task.TaskType, task.Weight, obj.CurrentTimeSlot, obj.CurrentTimeSlot);
                    obj.Cache(task.TaskType) = entry;
                    obj.UsedCacheSize = obj.UsedCacheSize + task.Weight;
                    obj.CacheInsertOrder(end+1) = task.TaskType;
                end
                
                success = true;
            else
                success = false;
            end
        end
        
        function selectedTasks = solveKnapsack(obj, items, capacity)
            % 01背包算法求解
            n = length(items);
            if n == 0
                selectedTasks = {};
                return;
            end
            
            % 将容量转换为整数以便动态规划
            intCapacity = floor(capacity);
            
            % dp(i,w) 表示前i个物品在容量为w时的最大价值
            dp = zeros(n+1, intCapacity+1);
            
            % 填充动态规划表
            for i = 1:n
                for w = 0:intCapacity
                    item = items{i};
                    itemWeight = floor(item.Weight);
                    
                    if itemWeight <= w
                        % 可以选择当前物品
                        takeValue = dp(i, w-itemWeight+1) + item.Value;
                        notTakeValue = dp(i, w+1);
                        dp(i+1, w+1) = max(takeValue, notTakeValue);
                    else
                        % 不能选择当前物品
                        dp(i+1, w+1) = dp(i, w+1);
                    end
                end
            end
            
            % 回溯找出选中的物品
            selectedTasks = {};
            w = intCapacity + 1;
            for i = n:-1:1
                if dp(i+1, w) ~= dp(i, w)
                    selectedTasks{end+1} = items{i};
                    w = w - floor(items{i}.Weight);
                end
            end
        end
        
        function totalValue = getCacheTotalValue(obj, taskManager)
            % 获取当前缓存中所有任务类型的总价值
            % 价值 = 访问频率 * 优先级
            totalValue = 0;
            
            keys = cell2mat(obj.Cache.keys);
            for i = 1:length(keys)
                taskType = keys(i);
                if taskManager.TaskTypes.isKey(taskType)
                    tt = taskManager.TaskTypes(taskType);
                    value = obj.AccessFrequency(taskType) * tt.Priority;
                    totalValue = totalValue + value;
                end
            end
        end
    end
end