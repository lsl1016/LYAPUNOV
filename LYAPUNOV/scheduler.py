"""
调度器类
从MATLAB版本转换而来，保留所有原始逻辑和注释
"""

import numpy as np
from scipy.optimize import linear_sum_assignment
# 处理导入问题
try:
    from .constants import Constants
    from .task_classes import SchedulingResult, TaskValue2
except ImportError:
    from constants import Constants
    from task_classes import SchedulingResult, TaskValue2


class Scheduler:
    """Scheduler 调度器"""
    
    def __init__(self, algorithm, vv=None):
        """构造函数"""
        if vv is None:
            vv = Constants.VV_DEFAULT
        self.Algorithm = algorithm
        self.LyapunovVV = vv
        
    def schedule_tasks(self, mec, task_manager, lyapunov_manager):
        """根据指定的算法调用相应的调度函数"""
        if self.Algorithm == Constants.GreedySchedule:
            return self.greedy_schedule(mec, task_manager)
        elif self.Algorithm == Constants.ShortTermSchedule:
            return self.short_term_schedule(mec, task_manager, lyapunov_manager)
        elif self.Algorithm == Constants.LyapunovSchedule:
            return self.lyapunov_schedule(mec, task_manager, lyapunov_manager)
        elif self.Algorithm == Constants.NoCacheSchedule:
            # 无缓存调度可以复用李雅普诺夫调度，但在Simulator层面需禁用缓存
            return self.lyapunov_schedule(mec, task_manager, lyapunov_manager)
        else:
            return []

    def greedy_schedule(self, mec, task_manager):
        """TODO: 修正算法"""
        results = []
        
        # 获取所有积压任务和空闲节点
        backlog_tasks = task_manager.get_all_backlog_tasks()  # TaskValue2 objects
        idle_nodes = mec.get_idle_nodes()
        
        # 如果没有任务或没有空闲节点，直接返回
        if len(backlog_tasks) == 0 or len(idle_nodes) == 0:
            return results
        
        # 按任务优先级降序排序
        backlog_tasks.sort(key=lambda x: x.Priority, reverse=True)
        
        # 按节点计算频率降序排序
        idle_nodes.sort(key=lambda x: x.ComputeFrequency, reverse=True)
        
        num_to_schedule = min(len(backlog_tasks), len(idle_nodes))
        scheduled_task_types = set()

        for i in range(num_to_schedule):
            task_info = backlog_tasks[i]
            node = idle_nodes[i]
            
            # 跳过已调度过的任务类型
            if task_info.TaskType in scheduled_task_types:
                continue

            # 从积压队列中获取一个真实的任务实例以检查其属性
            real_task = task_manager.peek_task_from_backlog(task_info.TaskType)
            if real_task is None:
                continue  # 如果队列为空，则跳过
            
            # 检查时延约束
            required_slots = task_manager.calculate_wkr(real_task.MKR, real_task.Ck)
            if required_slots > (real_task.SKR - real_task.Age):
                continue  # 如果不满足时延约束，则不调度

            # 调度任务
            if mec.schedule_task(task_info.TaskType, node.ID, real_task.MKR, real_task.Ck):
                res = SchedulingResult()
                res.TaskType = task_info.TaskType
                res.NodeID = node.ID
                res.MKR = real_task.MKR
                res.CompletedTasks = 1  # 贪心调度一次只处理一个任务
                results.append(res)
                
                scheduled_task_types.add(task_info.TaskType)
        
        return results
        
    def lyapunov_schedule(self, mec, task_manager, lyapunov_manager):
        """李雅普诺夫调度算法"""
        results = []

        candidate_tasks = self.get_candidate_tasks(mec, task_manager)
        idle_nodes = mec.get_idle_nodes()

        if len(candidate_tasks) == 0 or len(idle_nodes) == 0:
            return results

        num_tasks = len(candidate_tasks)
        num_nodes = len(idle_nodes)
        
        weight_matrix = np.full((num_tasks, num_nodes), np.inf)
        task_details = [None] * num_tasks

        for i in range(num_tasks):
            task_info = candidate_tasks[i]

            # -- 开始执行严格的TODO逻辑 --
            all_tasks_of_type = task_manager.get_backlog_tasks(task_info.TaskType)
            best_task_for_type = None
            min_required_freq = float('inf')

            for current_task in all_tasks_of_type:
                deadline_slots = current_task.SKR - current_task.Age
                if deadline_slots <= 0:
                    continue
                required_freq = (current_task.Ck * current_task.MKR) / (deadline_slots * Constants.Tslot) / 1e6
                
                if required_freq < min_required_freq:
                    min_required_freq = required_freq
                    best_task_for_type = current_task
            # -- 严格TODO逻辑结束 --

            if best_task_for_type is None:
                task_details[i] = None
                continue
            task_details[i] = best_task_for_type
            
            queue_length = lyapunov_manager.get_queue_length(task_info.TaskType)
            
            for j in range(num_nodes):
                node = idle_nodes[j]
                
                if node.ComputeFrequency < min_required_freq:
                    weight_matrix[i, j] = np.inf
                    continue
                
                required_slots = task_manager.calculate_wkr(best_task_for_type.MKR, best_task_for_type.Ck)
                frequency_ghz = node.ComputeFrequency / 1000.0
                energy_cost = Constants.AFIE * (frequency_ghz ** 3) * Constants.NMT * required_slots
                service_rate = 1 / required_slots
                
                revenue = Constants.WCOM * task_info.Priority - energy_cost
                
                weight_matrix[i, j] = queue_length * service_rate - self.LyapunovVV * revenue
        
        # 将无效任务的权重设为无穷大
        for i in range(num_tasks):
            if task_details[i] is None:
                weight_matrix[i, :] = np.inf

        # 使用贪心匹配算法（因为scipy的匈牙利算法要求有限权重）
        assigned_tasks = [False] * num_tasks
        assigned_nodes = [False] * num_nodes
        
        # 获取所有有效的(任务,节点)对，按权重排序
        valid_pairs = []
        for i in range(num_tasks):
            for j in range(num_nodes):
                if weight_matrix[i, j] < np.inf:
                    valid_pairs.append((weight_matrix[i, j], i, j))
        
        valid_pairs.sort()  # 按权重升序排序
        
        num_to_schedule = min(num_tasks, num_nodes)
        count_scheduled = 0
        
        for weight, i, j in valid_pairs:
            if count_scheduled >= num_to_schedule:
                break
                
            if not assigned_tasks[i] and not assigned_nodes[j]:
                task_info = candidate_tasks[i]
                node = idle_nodes[j]
                real_task = task_details[i]

                if mec.schedule_task(task_info.TaskType, node.ID, real_task.MKR, real_task.Ck):
                    res = SchedulingResult()
                    res.TaskType = task_info.TaskType
                    res.NodeID = node.ID
                    res.MKR = real_task.MKR
                    res.CompletedTasks = 1
                    results.append(res)
                    
                    assigned_tasks[i] = True
                    assigned_nodes[j] = True
                    count_scheduled += 1
        
        return results
        
    def get_candidate_tasks(self, mec, task_manager):
        """获取候选调度任务（排除缓存命中和正在计算的任务类型）"""
        candidate_tasks = []
        
        for task_type in task_manager.BacklogQueue:
            backlog_count = task_manager.get_backlog_count(task_type)
            
            if (backlog_count > 0 and 
                not mec.is_cache_hit(task_type) and 
                not mec.is_task_type_computing(task_type)):
                # 该任务类型在积压队列中且未缓存命中且未在计算
                tt = task_manager.TaskTypes[task_type]
                access_freq = mec.AccessFrequency[task_type]
                candidate_tasks.append(TaskValue2(task_type, tt.Priority, access_freq, backlog_count, 0))
        
        return candidate_tasks
        
    def sort_tasks_by_value(self, candidate_tasks):
        """按价值（访问频率*优先级）排序任务"""
        if len(candidate_tasks) == 0:
            return []
        
        # 按价值降序排序
        candidate_tasks.sort(key=lambda x: x.Value, reverse=True)
        return candidate_tasks
        
    def hungarian_algorithm(self, cost_matrix):
        """
        匈牙利算法实现（简化版本）
        使用scipy.optimize.linear_sum_assignment来替代复杂的匈牙利算法实现
        """
        m, n = cost_matrix.shape
        if m == 0 or n == 0:
            return []
        
        # 处理非方形矩阵
        if m < n:
            # 添加虚拟行
            cost_matrix = np.vstack([cost_matrix, np.full((n - m, n), np.inf)])
        elif m > n:
            # 添加虚拟列
            cost_matrix = np.hstack([cost_matrix, np.full((m, m - n), np.inf)])
        
        try:
            # 使用scipy的匈牙利算法求解分配问题
            row_indices, col_indices = linear_sum_assignment(cost_matrix)
            
            # 转换为匹配格式
            matching = [-1] * m
            for i, j in zip(row_indices, col_indices):
                if i < m and j < n and cost_matrix[i, j] < np.inf:
                    matching[i] = j
                else:
                    matching[i] = -1  # 无匹配
            
            return matching[:m]  # 只返回原始任务数量的匹配
        except:
            # 如果scipy不可用，使用简单的贪心匹配
            print('scipy不可用，使用简单贪心匹配')
            return self.greedy_matching(cost_matrix[:m, :n])
        
    def greedy_matching(self, cost_matrix):
        """简单的贪心匹配算法（作为备选方案）"""
        m, n = cost_matrix.shape
        matching = [-1] * m
        used_cols = [False] * n
        
        for i in range(m):
            min_val = np.inf
            min_col = -1
            # 找到最小值且未被使用的列
            for j in range(n):
                if cost_matrix[i, j] < min_val and not used_cols[j]:
                    min_val = cost_matrix[i, j]
                    min_col = j
            
            if min_col != -1 and min_val < np.inf:
                matching[i] = min_col
                used_cols[min_col] = True
        
        return matching
    
    def short_term_schedule(self, mec, task_manager, lyapunov_manager):
        """
        TODO：下面这个也是KM匹配，但是不考虑李雅普诺夫队列
        短期调度算法（调度算法2）[KM匹配策略]
        """
        results = []
        
        candidate_tasks = self.get_candidate_tasks(mec, task_manager)
        idle_nodes = mec.get_idle_nodes()
        
        if len(candidate_tasks) == 0 or len(idle_nodes) == 0:
            return results
        
        num_tasks = len(candidate_tasks)
        num_nodes = len(idle_nodes)
        
        weight_matrix = np.full((num_tasks, num_nodes), -np.inf)
        task_details = [None] * num_tasks

        for i in range(num_tasks):
            task_info = candidate_tasks[i]
            
            # -- 开始执行严格的TODO逻辑 --
            all_tasks_of_type = task_manager.get_backlog_tasks(task_info.TaskType)
            best_task_for_type = None
            min_required_freq = float('inf')

            for current_task in all_tasks_of_type:
                deadline_slots = current_task.SKR - current_task.Age
                if deadline_slots <= 0:
                    continue
                required_freq = (current_task.Ck * current_task.MKR) / (deadline_slots * Constants.Tslot) / 1e6
                
                if required_freq < min_required_freq:
                    min_required_freq = required_freq
                    best_task_for_type = current_task
            # -- 严格TODO逻辑结束 --

            if best_task_for_type is None:
                task_details[i] = None
                continue
            task_details[i] = best_task_for_type

            for j in range(num_nodes):
                node = idle_nodes[j]
                
                # 检查节点是否满足最低频率要求
                if node.ComputeFrequency < min_required_freq:
                    weight_matrix[i, j] = -np.inf
                    continue
                
                required_slots = task_manager.calculate_wkr(best_task_for_type.MKR, best_task_for_type.Ck)
                frequency_ghz = node.ComputeFrequency / 1000.0
                energy_cost = Constants.AFIE * (frequency_ghz ** 3) * Constants.NMT * required_slots
                
                weight_matrix[i, j] = Constants.WCOM * task_info.Priority - energy_cost
        
        # 将无效任务的权重设为负无穷
        for i in range(num_tasks):
            if task_details[i] is None:
                weight_matrix[i, :] = -np.inf
        
        # 使用贪心匹配算法（按权重降序）
        assigned_tasks = [False] * num_tasks
        assigned_nodes = [False] * num_nodes
        
        # 获取所有有效的(任务,节点)对，按权重降序排序
        valid_pairs = []
        for i in range(num_tasks):
            for j in range(num_nodes):
                if weight_matrix[i, j] > -np.inf:
                    valid_pairs.append((weight_matrix[i, j], i, j))
        
        valid_pairs.sort(reverse=True)  # 按权重降序排序
        
        num_to_schedule = min(num_tasks, num_nodes)
        count_scheduled = 0
        
        for weight, i, j in valid_pairs:
            if count_scheduled >= num_to_schedule:
                break
                
            if not assigned_tasks[i] and not assigned_nodes[j]:
                task_info = candidate_tasks[i]
                node = idle_nodes[j]
                real_task = task_details[i]

                if mec.schedule_task(task_info.TaskType, node.ID, real_task.MKR, real_task.Ck):
                    res = SchedulingResult()
                    res.TaskType = task_info.TaskType
                    res.NodeID = node.ID
                    res.MKR = real_task.MKR
                    res.CompletedTasks = 1
                    results.append(res)
                    
                    assigned_tasks[i] = True
                    assigned_nodes[j] = True
                    count_scheduled += 1
        
        return results
        
    def no_cache_schedule(self, mec, task_manager, lyapunov_manager):
        """无缓存调度算法的实现"""
        return self.lyapunov_schedule(mec, task_manager, lyapunov_manager)
