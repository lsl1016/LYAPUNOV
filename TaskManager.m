classdef TaskManager < handle
    % TaskManager 管理所有任务类型和任务实例

    properties
        TaskTypes    % 任务类型映射 (containers.Map)
        BacklogQueue % 积压队列，按任务类型分组 (containers.Map)
        nextTaskID   % 下一个任务ID
    end

    methods
        function obj = TaskManager()
            % 构造函数
            obj.TaskTypes = containers.Map('KeyType', 'int32', 'ValueType', 'any');
            obj.BacklogQueue = containers.Map('KeyType', 'int32', 'ValueType', 'any');
            obj.nextTaskID = 1;

            % 初始化任务类型配置
            obj.initTaskTypeConfig();
        end

        function initTaskTypeConfig(obj)
            % 初始化任务类型配置（任务类型静态信息）
            K = constants.K();

            for i = 1:K
                % 生成随机任务类型参数
                priority = randi([constants.MIN_PRIORITY, constants.MAX_PRIORITY]);
                ck = randi([constants.MIN_CK, constants.MAX_CK]);
                metaK = randi([constants.MIN_METAK, constants.MAX_METAK]);
                pk = rand(); % 0~1之间的随机值

                % 创建任务类型对象
                taskType = TaskType(i, priority, ck, metaK, pk);
                obj.TaskTypes(i) = taskType;

                % 初始化积压队列
                obj.BacklogQueue(i) = {};
            end
        end

        function task = generateTask(obj, taskType, currentTimeSlot)
            % 根据任务类型生成具体任务
            if ~obj.TaskTypes.isKey(taskType)
                error('无效的任务类型: %d', taskType);
            end

            tt = obj.TaskTypes(taskType);
            mkr = randi([constants.MIN_MKR, constants.MAX_MKR]);  % 输入数据量
            skr = randi([constants.MIN_SKR, constants.MAX_SKR]);  % 时延预警值

            task = task(obj.nextTaskID, taskType, tt.Priority, skr, mkr, tt.Ck, tt.MetaK, currentTimeSlot);
            obj.nextTaskID = obj.nextTaskID + 1;
        end

        % TODO：我希望从长期看每个时隙生成的任务类型的数量比例是每个任务类型的概率
        function tasks = generateRandomTasks(obj, currentTime)
            % 按概率生成每时隙的任务
            tasks = {};
            numTasksToGenerate = constants.N();
            K = constants.K();
            
            % 准备轮盘赌选择
            % 确保概率是按任务类型ID (1 to K) 顺序排列
            probabilities = zeros(1, K);
            for i = 1:K
                if obj.TaskTypes.isKey(i)
                    tt = obj.TaskTypes(i);
                    probabilities(i) = tt.PK;
                end
            end
            
            % 创建累积分布函数(CDF)
            cdf = cumsum(probabilities);
            
            for i = 1:numTasksToGenerate
                % 生成一个 (0, 1] 之间的随机数
                randVal = rand();
                
                % 轮盘赌选择, find返回的索引就是任务类型的ID
                taskTypeID = find(randVal <= cdf, 1, 'first');
                
                if ~isempty(taskTypeID) && obj.TaskTypes.isKey(taskTypeID)
                    selectedTaskType = obj.TaskTypes(taskTypeID); % 这是TaskType对象
                    
                    % 随机生成mkr和skr
                    mkr = randi([constants.MIN_MKR, constants.MAX_MKR]);
                    skr = randi([constants.MIN_SKR, constants.MAX_SKR]);
                    
                    % 创建任务实例
                    task = task( ...
                        obj.nextTaskID, ...
                        taskTypeID, ... % <<< 修正：直接使用taskTypeID
                        selectedTaskType.Priority, ...
                        skr, ...
                        mkr, ...
                        selectedTaskType.Ck, ...
                        selectedTaskType.MetaK, ...
                        currentTime ...
                        );
                    
                    tasks{end+1} = task;
                    obj.nextTaskID = obj.nextTaskID + 1;
                end
            end
        end

        function addToBacklog(obj, task)
            % 将任务添加到积压队列
            backlogQueue = obj.BacklogQueue(task.TaskType);
            backlogQueue{end+1} = task;
            obj.BacklogQueue(task.TaskType) = backlogQueue;
        end

        function expiredCount = removeExpiredTasks(obj, currentTimeSlot)
            % 移除过期任务的计数
            expiredCount = containers.Map('KeyType', 'int32', 'ValueType', 'int32');

            keys = cell2mat(obj.BacklogQueue.keys);
            for i = 1:length(keys)
                taskType = keys(i);
                tasks = obj.BacklogQueue(taskType);
                remainingTasks = {};
                expired = 0;

                for j = 1:length(tasks)
                    task = tasks{j};
                    task.Age = (currentTimeSlot - task.CreateTime);
                    % 检查是否过期
                    if task.Age > task.SKR
                        expired = expired + 1;
                    else
                        remainingTasks{end+1} = task;
                    end
                end

                obj.BacklogQueue(taskType) = remainingTasks;
                expiredCount(taskType) = expired;
            end
        end

        function count = getBacklogCount(obj, taskType)
            % 获取积压队列中指定类型任务的数量
            if obj.BacklogQueue.isKey(taskType)
                backlogQueue = obj.BacklogQueue(taskType);
                count = length(backlogQueue);
            else
                count = 0;
            end
        end

        function removeTasksFromBacklog(obj, taskType, count)
            % 从积压队列中移除指定类型的任务
            if count <= 0
                return;
            end

            if obj.BacklogQueue.isKey(taskType)
                tasks = obj.BacklogQueue(taskType);
                if count >= length(tasks)
                    obj.BacklogQueue(taskType) = {};
                else
                    obj.BacklogQueue(taskType) = tasks((count+1):end);
                end
            end
        end

        function tasks = getBacklogTasks(obj, taskType)
            % 获取指定类型积压队列中的所有任务
            tasks = {};
            if obj.BacklogQueue.isKey(taskType)
                tasks = obj.BacklogQueue(taskType);
            end
        end
        
        function task = peekTaskFromBacklog(obj, taskType)
            % 查看但不移除指定类型积压队列中的第一个任务
            task = [];
            if obj.BacklogQueue.isKey(taskType)
                queue = obj.BacklogQueue(taskType);
                if ~isempty(queue)
                    task = queue{1};
                end
            end
        end
        
        function allTasks = getAllBacklogTasks(obj)
            % 获取所有积压队列中的任务，返回TaskValue2列表
            allTasks = {};
            taskTypeKeys = cell2mat(obj.BacklogQueue.keys);
            for i = 1:length(taskTypeKeys)
                taskType = taskTypeKeys(i);
                if ~isempty(obj.BacklogQueue(taskType))
                    % 只需要类型和优先级用于调度决策
                    tt = obj.TaskTypes(taskType);
                    allTasks{end+1} = TaskValue2(taskType, tt.Priority);
                end
            end
        end

    end

    methods (Static)
        % 第k类型任务调度到第r个虚拟节点上计算，所占用的时隙数量
        function wkr = calculateWKR(mkr, ck)
            % 计算wkr(t) - 虚拟节点以最小计算频率计算任务所占用的时隙数量
            wkr = ceil((mkr * ck / constants.FM) / constants.Tslot);
        end

        % 计算占用时隙数量
        function occupiedSlots = calculateSchedulingSlots(mkr, ck, nodeFrequency)
            occupiedSlots = ceil((mkr * ck / nodeFrequency) / constants.Tslot);
        end

        function bkr = calculateBKR(mkr, ck, nodeFrequency, isCacheHit)
            % 计算bkr(t) - 调度任务所带来的时隙数量增益
            wkr = TaskManager.calculateWKR(mkr, ck);

            if isCacheHit
                bkr = wkr;
            else
                occupiedSlots = TaskManager.calculateSchedulingSlots(mkr, ck, nodeFrequency);
                bkr = wkr - occupiedSlots;
            end
        end

        function printTaskTypeStaticInfo(obj)
            % 追加打印任务类型的静态信息 到 log.txt文件中
            fid = fopen('log.txt', 'a');
            fprintf(fid, '时间戳: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
            fprintf(fid, '任务类型静态信息:\n');

            % 直接遍历已知的任务类型数量，使用try-catch避免错误
            K = constants.K();
            for i = 1:K
                try
                    taskTypeObj = obj.TaskTypes(i);
                    fprintf(fid, '任务类型 %d: 优先级=%d, 计算复杂度=%d, 元数据量大小=%d, 产生概率=%.4f\n', ...
                        i, taskTypeObj.Priority, taskTypeObj.Ck, ...
                        taskTypeObj.MetaK, taskTypeObj.PK);
                catch
                    fprintf(fid, '任务类型 %d: 未初始化或访问错误\n', i);
                end
            end
            fprintf(fid, '\n');
            fclose(fid);
        end
    end
end
