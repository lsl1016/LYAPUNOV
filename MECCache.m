% MECCache.m - MEC缓存相关方法的扩展
% 这个文件包含MEC类的缓存操作方法


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
    success = applyCacheReplacementStrategy(obj, taskType, metaSize, taskManager);
end

function success = applyCacheReplacementStrategy(obj, newTaskType, newMetaSize, taskManager)
    % 应用缓存替换策略
    switch obj.CacheStrategy
        case constants.FIFO
            success = applyFIFO(obj, newTaskType, newMetaSize);
        case constants.LFU
            success = applyLFU(obj, newTaskType, newMetaSize, taskManager);
        case constants.LRU
            success = applyLRU(obj, newTaskType, newMetaSize, taskManager);
        case constants.Priority
            success = applyPriority(obj, newTaskType, newMetaSize, taskManager);
        case constants.Knapsack
            success = applyKnapsack(obj, newTaskType, newMetaSize, taskManager);
        otherwise
            success = applyFIFO(obj, newTaskType, newMetaSize);
    end
end

%
% 拿到原来的队列，用新的任务类型去挤掉老的任务类型
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
        success = addToCache(obj, newTaskType, newMetaSize, taskManager);
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
        success = addToCache(obj, newTaskType, newMetaSize, taskManager);
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
            success = addToCache(obj, newTaskType, newMetaSize, taskManager);
        else
            success = false;
        end
    else
        success = false;
    end
end

% 和之前一样，当前时隙可能有多个新任务类型
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
    selectedTasks = solveKnapsack(obj, candidates, constants.totalCacheSize());
    
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
