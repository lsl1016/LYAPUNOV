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
        
        function completedTaskTypesMap = updateNodes(obj)
            % 更新所有虚拟节点状态（每个时隙调用）
            % 返回一个map, key=taskType, value=count (这里count总是1)
            completedTaskTypesMap = containers.Map('KeyType', 'int32', 'ValueType', 'int32');
            
            for i = 1:length(obj.VirtualNodes)
                node = obj.VirtualNodes{i};
                if ~node.IsIdle
                    node.RemainingSlots = node.RemainingSlots - 1;
                    if node.RemainingSlots <= 0
                        % 任务计算完成
                        taskType = node.CurrentTaskType;
                        if completedTaskTypesMap.isKey(taskType)
                            completedTaskTypesMap(taskType) = completedTaskTypesMap(taskType) + 1;
                        else
                            completedTaskTypesMap(taskType) = 1;
                        end

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
        
        % TODO:修正： 当前时隙的计算收益计算方式为（在仿真函数的% 4. 调度积压队列中的任务 后计算 ）：调度的任务的任务类型的计算优先级*wcom -  constants.AFIE * (frequencyGHz^3) * constants.NMT * 计算这个任务占用的时隙数量 （需要注意的是如果这个任务在虚拟节点上需要多个时隙才能计算完成，不要重复计算）
        % 有一种情况需要累加：那就是在未来某个时隙，在虚拟节点上计算完成获得结果，清空积压队列这个类型的任务数据时：加上 ：调度的任务的任务类型的计算优先级*wcom*这一时隙的积压队列中这个类型的任务数量

        % TODO 修正：当前时隙的缓存命中收益为，对于当前时隙，如果缓存命中，则缓存命中收益为 计算任务的计算优先级*whit*当前时隙该类型任务的命中个数 -  constants.BETA * 当前时隙该类型任务的元数据大小（这个元数据大小，当前时隙同一类型任务应该只计算一次）（不要重复计算之前时隙的缓存收益了，它们应该是在之前时隙被计算过了）
        function updateRevenue(obj, taskManager, scheduledTasks, completedTasks, cacheHitTasks)
            % scheduledTasks: map[taskType] -> {node, mkr, ck, backlogCount}
            % completedTasks: map[taskType] -> backlogCount
            % cacheHitTasks: map[taskType] -> {backlogCount, metaK}

            currentIncome = 0;
            currentCost = 0;

            % --- 1. 计算任务完成的收益 ---
            % 对应TODO的第二部分：在未来某个时隙...计算完成获得结果...加上...
            completedTaskTypes = cell2mat(keys(completedTasks));
            for i = 1:length(completedTaskTypes)
                taskType = completedTaskTypes(i);
                backlogCount = completedTasks(taskType);
                if taskManager.TaskTypes.isKey(taskType)
                    tt = taskManager.TaskTypes(taskType);
                    currentIncome = currentIncome + constants.WCOM * tt.Priority * backlogCount;
                end
            end

            % --- 2. 计算缓存命中的收益和成本 ---
            % 对应TODO: 缓存命中收益为...优先级*whit*命中个数 - BETA*元数据大小
            cacheHitTaskTypes = cell2mat(keys(cacheHitTasks));
            for i = 1:length(cacheHitTaskTypes)
                taskType = cacheHitTaskTypes(i);
                hitInfo = cacheHitTasks(taskType);
                if taskManager.TaskTypes.isKey(taskType)
                    tt = taskManager.TaskTypes(taskType);
                    % 收益部分
                    currentIncome = currentIncome + constants.WHIT * tt.Priority * hitInfo.backlogCount;
                    % 成本部分 (每个命中的任务类型只计算一次元数据成本)
                    currentCost = currentCost + constants.BETA * tt.MetaK;
                end
            end
            
            % --- 3. 计算新调度任务的成本 (主要是能耗) ---
            % 对应TODO: ...成本为... AFIE * (frequencyGHz^3) * NMT * 时隙数量
            scheduledTaskTypes = cell2mat(keys(scheduledTasks));
            for i = 1:length(scheduledTaskTypes)
                taskType = scheduledTaskTypes(i);
                taskInfo = scheduledTasks(taskType);
                node = taskInfo.node;
                
                frequencyGHz = node.ComputeFrequency / 1000.0;
                requiredSlots = TaskManager.calculateWKR(taskInfo.mkr, taskInfo.ck);
                
                % 注意: 此处不计算WCOM相关的收益，因为那部分在任务完成时才获得
                currentCost = currentCost + constants.AFIE * (frequencyGHz^3) * constants.NMT * requiredSlots;
            end
            
            % --- 4. 累加总收益和成本 ---
            obj.Income = obj.Income + currentIncome;
            obj.Cost = obj.Cost + currentCost;
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