classdef Scheduler < handle
    % Scheduler 调度器
    
    properties
        Algorithm  % 调度算法类型
        LyapunovVV % 李雅普诺夫漂移参数
    end
    
    methods
        function obj = Scheduler(algorithm, vv)
            % 构造函数
            if nargin < 2
                vv = constants.VV_DEFAULT;
            end
            obj.Algorithm = algorithm;
            obj.LyapunovVV = vv;
        end
        
        function results = scheduleTasks(obj, mec, taskManager, lyapunovManager)
            % 根据指定的算法调用相应的调度函数
            switch obj.Algorithm
                case constants.GreedySchedule
                    results = obj.greedySchedule(mec, taskManager);
                case constants.ShortTermSchedule
                    results = obj.shortTermSchedule(mec, taskManager, lyapunovManager);
                case constants.LyapunovSchedule
                    results = obj.lyapunovSchedule(mec, taskManager, lyapunovManager);
                case constants.NoCacheSchedule
                    % 无缓存调度可以复用李雅普诺夫调度，但在Simulator层面需禁用缓存
                    results = obj.lyapunovSchedule(mec, taskManager, lyapunovManager);
                otherwise
                    results = {};
            end
        end

        % TODO: 修正算法

        function results = greedySchedule(obj, mec, taskManager)
            results = {};
            
            % 获取所有积压任务和空闲节点
            backlogTasks = taskManager.getAllBacklogTasks(); % TaskValue2 objects
            idleNodes = mec.getIdleNodes();
            
            % 如果没有任务或没有空闲节点，直接返回
            if isempty(backlogTasks) || isempty(idleNodes)
                return;
            end
            
            % 按任务优先级降序排序
            [~, sortedTaskIndices] = sort(cellfun(@(x) x.Priority, backlogTasks), 'descend');
            
            % 按节点计算频率降序排序
            [~, sortedNodeIndices] = sort(cellfun(@(x) x.ComputeFrequency, idleNodes), 'descend');
            
            numToSchedule = min(length(backlogTasks), length(idleNodes));
            scheduledTaskTypes = containers.Map('KeyType', 'int32', 'ValueType', 'logical');

            for i = 1:numToSchedule
                taskInfo = backlogTasks{sortedTaskIndices(i)};
                node = idleNodes{sortedNodeIndices(i)};
                
                % 跳过已调度过的任务类型
                if isKey(scheduledTaskTypes, taskInfo.TaskType)
                    continue;
                end

                % 从积压队列中获取一个真实的任务实例以检查其属性
                realTask = taskManager.peekTaskFromBacklog(taskInfo.TaskType);
                if isempty(realTask)
                    continue; % 如果队列为空，则跳过
                end
                
                % 检查时延约束
                requiredSlots = TaskManager.calculateWKR(realTask.MKR, realTask.Ck);
                if requiredSlots > (realTask.SKR - realTask.Age)
                    continue; % 如果不满足时延约束，则不调度
                end

                % 调度任务
                if mec.scheduleTask(taskInfo.TaskType, node.ID, realTask.MKR, realTask.Ck)
                    res = SchedulingResult();
                    res.TaskType = taskInfo.TaskType;
                    res.NodeID = node.ID;
                    res.MKR = realTask.MKR;
                    res.CompletedTasks = 1; % 贪心调度一次只处理一个任务
                    results{end+1} = res;
                    
                    scheduledTaskTypes(taskInfo.TaskType) = true;
                end
            end
        end
        
        function results = lyapunovSchedule(obj, mec, taskManager, lyapunovManager)
            results = {};

            candidateTasks = obj.getCandidateTasks(mec, taskManager);
            idleNodes = mec.getIdleNodes();

            if isempty(candidateTasks) || isempty(idleNodes)
                return;
            end

            numTasks = length(candidateTasks);
            numNodes = length(idleNodes);
            
            weightMatrix = zeros(numTasks, numNodes);
            taskDetails = cell(numTasks, 1);

            for i = 1:numTasks
                taskInfo = candidateTasks{i};

                % -- 开始执行严格的TODO逻辑 --
                all_tasks_of_type = taskManager.getBacklogTasks(taskInfo.TaskType);
                best_task_for_type = [];
                min_required_freq = inf;

                for k = 1:length(all_tasks_of_type)
                    currentTask = all_tasks_of_type{k};
                    deadline_slots = currentTask.SKR - currentTask.Age;
                    if deadline_slots <= 0
                        continue;
                    end
                    required_freq = (currentTask.Ck * currentTask.MKR) / (deadline_slots * constants.Tslot) / 1e6;
                    
                    if required_freq < min_required_freq
                        min_required_freq = required_freq;
                        best_task_for_type = currentTask;
                    end
                end
                % -- 严格TODO逻辑结束 --

                if isempty(best_task_for_type)
                    taskDetails{i} = [];
                    continue; 
                end
                taskDetails{i} = best_task_for_type;
                
                queueLength = lyapunovManager.getQueueLength(taskInfo.TaskType);
                
                for j = 1:numNodes
                    node = idleNodes{j};
                    
                    if node.ComputeFrequency < min_required_freq
                        weightMatrix(i, j) = inf;
                        continue;
                    end
                    
                    requiredSlots = TaskManager.calculateWKR(best_task_for_type.MKR, best_task_for_type.Ck);
                    frequencyGHz = node.ComputeFrequency / 1000.0;
                    energyCost = constants.AFIE * (frequencyGHz^3) * constants.NMT * requiredSlots;
                    serviceRate = 1 / requiredSlots;
                    
                    revenue = constants.WCOM * taskInfo.Priority - energyCost;
                    
                    weightMatrix(i, j) = queueLength * serviceRate - obj.LyapunovVV * revenue;
                end
            end
            
            for i = 1:numTasks
                if isempty(taskDetails{i})
                    weightMatrix(i,:) = inf;
                end
            end

            [~, sorted_indices] = sort(weightMatrix(:), 'ascend');
            
            assigned_tasks = false(1, numTasks);
            assigned_nodes = false(1, numNodes);
            
            numToSchedule = min(numTasks, numNodes);
            countScheduled = 0;
            
            for k = 1:length(sorted_indices)
                if countScheduled >= numToSchedule
                    break;
                end
                
                [i, j] = ind2sub(size(weightMatrix), sorted_indices(k));
                
                if ~assigned_tasks(i) && ~assigned_nodes(j) && weightMatrix(i,j) < inf
                    taskInfo = candidateTasks{i};
                    node = idleNodes{j};
                    realTask = taskDetails{i};

                    if mec.scheduleTask(taskInfo.TaskType, node.ID, realTask.MKR, realTask.Ck)
                        res = SchedulingResult();
                        res.TaskType = taskInfo.TaskType;
                        res.NodeID = node.ID;
                        res.MKR = realTask.MKR;
                        res.CompletedTasks = 1;
                        results{end+1} = res;
                        
                        assigned_tasks(i) = true;
                        assigned_nodes(j) = true;
                        countScheduled = countScheduled + 1;
                    end
                end
            end
        end
        
        function candidateTasks = getCandidateTasks(obj, mec, taskManager)
            % 获取候选调度任务（排除缓存命中和正在计算的任务类型）
            candidateTasks = {};
            
            keys = cell2mat(taskManager.BacklogQueue.keys);
            for i = 1:length(keys)
                taskType = keys(i);
                backlogCount = taskManager.getBacklogCount(taskType);
                
                if backlogCount > 0 && ~mec.isCacheHit(taskType) && ~mec.isTaskTypeComputing(taskType)
                    % 该任务类型在积压队列中且未缓存命中且未在计算
                    tt = taskManager.TaskTypes(taskType);
                    accessFreq = mec.AccessFrequency(taskType);
                    candidateTasks{end+1} = TaskValue2(taskType, tt.Priority, accessFreq, backlogCount, 0);
                end
            end
        end
        
        function sortedTasks = sortTasksByValue(obj, candidateTasks)
            % 按价值（访问频率*优先级）排序任务
            if isempty(candidateTasks)
                sortedTasks = {};
                return;
            end
            
            % 提取价值
            values = zeros(1, length(candidateTasks));
            for i = 1:length(candidateTasks)
                values(i) = candidateTasks{i}.Value;
            end
            
            % 排序（降序）
            [~, sortIndex] = sort(values, 'descend');
            
            sortedTasks = {};
            for i = 1:length(sortIndex)
                sortedTasks{end+1} = candidateTasks{sortIndex(i)};
            end
        end
        
        function matching = hungarianAlgorithm(obj, costMatrix)
            % 匈牙利算法实现（简化版本）
            % 这里使用MATLAB内置的assignmentoptimal函数来替代复杂的匈牙利算法实现
            
            [m, n] = size(costMatrix);
            if m == 0 || n == 0
                matching = [];
                return;
            end
            
            % 处理非方形矩阵
            if m < n
                % 添加虚拟行
                costMatrix = [costMatrix; inf(n-m, n)];
            elseif m > n
                % 添加虚拟列
                costMatrix = [costMatrix, inf(m, m-n)];
            end
            
            try
                % 使用MATLAB内置函数求解分配问题
                [assignment, ~] = assignmentoptimal(costMatrix);
                
                % 转换为匹配格式
                matching = zeros(1, m);
                for i = 1:m
                    if i <= length(assignment) && assignment(i) <= n
                        matching(i) = assignment(i);
                    else
                        matching(i) = -1; % 无匹配
                    end
                end
            catch
                % 如果没有优化工具箱，使用简单的贪心匹配
                warning('未找到assignmentoptimal函数，使用简单贪心匹配');
                matching = obj.greedyMatching(costMatrix(1:m, 1:n));
            end
        end
        
        function matching = greedyMatching(obj, costMatrix)
            % 简单的贪心匹配算法（作为备选方案）
            [m, n] = size(costMatrix);
            matching = -ones(1, m);
            usedCols = false(1, n);
            
            for i = 1:m
                [minVal, minCol] = min(costMatrix(i, :));
                % 找到最小值且未被使用的列
                for j = 1:n
                    if costMatrix(i, j) == minVal && ~usedCols(j)
                        matching(i) = j;
                        usedCols(j) = true;
                        break;
                    end
                end
            end
        end
        % TODO：下面这个也是KM匹配，但是不考虑李雅普诺夫队列
        function results = shortTermSchedule(obj, mec, taskManager, lyapunovManager)
            results = {};
            
            candidateTasks = obj.getCandidateTasks(mec, taskManager);
            idleNodes = mec.getIdleNodes();
            
            if isempty(candidateTasks) || isempty(idleNodes)
                return;
            end
            
            numTasks = length(candidateTasks);
            numNodes = length(idleNodes);
            
            weightMatrix = zeros(numTasks, numNodes);
            taskDetails = cell(numTasks, 1);

            for i = 1:numTasks
                taskInfo = candidateTasks{i};
                
                % -- 开始执行严格的TODO逻辑 --
                all_tasks_of_type = taskManager.getBacklogTasks(taskInfo.TaskType);
                best_task_for_type = [];
                min_required_freq = inf;

                for k = 1:length(all_tasks_of_type)
                    currentTask = all_tasks_of_type{k};
                    deadline_slots = currentTask.SKR - currentTask.Age;
                    if deadline_slots <= 0
                        continue;
                    end
                    required_freq = (currentTask.Ck * currentTask.MKR) / (deadline_slots * constants.Tslot) / 1e6;
                    
                    if required_freq < min_required_freq
                        min_required_freq = required_freq;
                        best_task_for_type = currentTask;
                    end
                end
                % -- 严格TODO逻辑结束 --

                if isempty(best_task_for_type)
                    taskDetails{i} = [];
                    continue;
                end
                taskDetails{i} = best_task_for_type;

                for j = 1:numNodes
                    node = idleNodes{j};
                    
                    % 检查节点是否满足最低频率要求
                    if node.ComputeFrequency < min_required_freq
                        weightMatrix(i, j) = -inf;
                        continue;
                    end
                    
                    requiredSlots = TaskManager.calculateWKR(best_task_for_type.MKR, best_task_for_type.Ck);
                    frequencyGHz = node.ComputeFrequency / 1000.0;
                    energyCost = constants.AFIE * (frequencyGHz^3) * constants.NMT * requiredSlots;
                    
                    weightMatrix(i, j) = constants.WCOM * taskInfo.Priority - energyCost;
                end
            end
            
            for i = 1:numTasks
                if isempty(taskDetails{i})
                    weightMatrix(i,:) = -inf;
                end
            end
            
            [~, sorted_indices] = sort(weightMatrix(:), 'descend');
            
            assigned_tasks = false(1, numTasks);
            assigned_nodes = false(1, numNodes);
            
            numToSchedule = min(numTasks, numNodes);
            countScheduled = 0;
            
            for k = 1:length(sorted_indices)
                if countScheduled >= numToSchedule
                    break;
                end
                
                [i, j] = ind2sub(size(weightMatrix), sorted_indices(k));
                
                if ~assigned_tasks(i) && ~assigned_nodes(j) && weightMatrix(i,j) > -inf
                    taskInfo = candidateTasks{i};
                    node = idleNodes{j};
                    realTask = taskDetails{i};

                    if mec.scheduleTask(taskInfo.TaskType, node.ID, realTask.MKR, realTask.Ck)
                        res = SchedulingResult();
                        res.TaskType = taskInfo.TaskType;
                        res.NodeID = node.ID;
                        res.MKR = realTask.MKR;
                        res.CompletedTasks = 1;
                        results{end+1} = res;
                        
                        assigned_tasks(i) = true;
                        assigned_nodes(j) = true;
                        countScheduled = countScheduled + 1;
                    end
                end
            end
        end
        
        function results = noCacheSchedule(obj, mec, taskManager, lyapunovManager)
            % 无缓存调度算法的实现
            results = obj.lyapunovSchedule(mec, taskManager, lyapunovManager);
        end
    end
end
