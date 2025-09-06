"""
任务管理器类
"""

import random
import math
from datetime import datetime
try:
    from .constants import Constants
    from .task_classes import Task, TaskType
except ImportError:
    from constants import Constants
    from task_classes import Task, TaskType, TaskValue2


class TaskManager:
    """TaskManager 管理所有任务类型和任务实例"""

    def __init__(self):
        """构造函数"""
        self.TaskTypes = {}      # 任务类型映射 (dict)
        self.BacklogQueue = {}   # 积压队列，按任务类型分组 (dict)
        self.nextTaskID = 1      # 下一个任务ID

        # 初始化任务类型配置
        self.init_task_type_config()

    def init_task_type_config(self):
        """初始化任务类型配置（任务类型静态信息）"""
        K = Constants.K()

        for i in range(1, K + 1):
            # 生成随机任务类型参数
            priority = random.randint(Constants.MIN_PRIORITY, Constants.MAX_PRIORITY)
            ck = random.randint(Constants.MIN_CK, Constants.MAX_CK)
            meta_k = random.randint(Constants.MIN_METAK, Constants.MAX_METAK)
            pk = random.random()  # 0~1之间的随机值

            # 创建任务类型对象
            task_type = TaskType(i, priority, ck, meta_k, pk)
            self.TaskTypes[i] = task_type

            # 初始化积压队列
            self.BacklogQueue[i] = []

    def generate_task(self, task_type, current_time_slot):
        """根据任务类型生成具体任务"""
        if task_type not in self.TaskTypes:
            raise ValueError(f'无效的任务类型: {task_type}')

        tt = self.TaskTypes[task_type]
        mkr = random.randint(Constants.MIN_MKR, Constants.MAX_MKR)  # 输入数据量
        skr = random.randint(Constants.MIN_SKR, Constants.MAX_SKR)  # 时延预警值

        task = Task(self.nextTaskID, task_type, tt.Priority, skr, mkr, tt.Ck, tt.MetaK, current_time_slot)
        self.nextTaskID += 1
        return task

    def generate_random_tasks(self, current_time):
        """
        按概率生成每时隙的任务
        """
        tasks = []
        num_tasks_to_generate = Constants.N()
        K = Constants.K()
        
        # 准备轮盘赌选择
        # 确保概率是按任务类型ID (1 to K) 顺序排列
        probabilities = []
        for i in range(1, K + 1):
            if i in self.TaskTypes:
                tt = self.TaskTypes[i]
                probabilities.append(tt.PK)
            else:
                probabilities.append(0)
        
        # 创建累积分布函数(CDF)
        total_prob = sum(probabilities)
        if total_prob > 0:
            probabilities = [p / total_prob for p in probabilities]  # 归一化
        
        cdf = []
        cumsum = 0
        for prob in probabilities:
            cumsum += prob
            cdf.append(cumsum)
        
        for _ in range(num_tasks_to_generate):
            # 生成一个 (0, 1] 之间的随机数
            rand_val = random.random()
            
            # 轮盘赌选择, 找到第一个大于等于随机值的CDF索引
            task_type_id = None
            for i, cumulative_prob in enumerate(cdf):
                if rand_val <= cumulative_prob:
                    task_type_id = i + 1  # 任务类型从1开始
                    break
            
            if task_type_id and task_type_id in self.TaskTypes:
                selected_task_type = self.TaskTypes[task_type_id]
                
                # 随机生成mkr和skr
                mkr = random.randint(Constants.MIN_MKR, Constants.MAX_MKR)
                skr = random.randint(Constants.MIN_SKR, Constants.MAX_SKR)
                
                # 创建任务实例
                task = Task(
                    self.nextTaskID,
                    task_type_id,  # 直接使用task_type_id
                    selected_task_type.Priority,
                    skr,
                    mkr,
                    selected_task_type.Ck,
                    selected_task_type.MetaK,
                    current_time
                )
                
                tasks.append(task)
                self.nextTaskID += 1
        
        return tasks

    def add_to_backlog(self, task):
        """将任务添加到积压队列"""
        if task.TaskType not in self.BacklogQueue:
            self.BacklogQueue[task.TaskType] = []
        self.BacklogQueue[task.TaskType].append(task)

    def remove_expired_tasks(self, current_time_slot):
        """移除过期任务的计数"""
        expired_count = {}

        for task_type in self.BacklogQueue:
            tasks = self.BacklogQueue[task_type]
            remaining_tasks = []
            expired = 0

            for task in tasks:
                task.Age = current_time_slot - task.CreateTime
                if task.Age > task.SKR:
                    expired += 1
                else:
                    remaining_tasks.append(task)

            self.BacklogQueue[task_type] = remaining_tasks
            expired_count[task_type] = expired

        return expired_count

    def get_backlog_count(self, task_type):
        """获取积压队列中指定类型任务的数量"""
        if task_type in self.BacklogQueue:
            return len(self.BacklogQueue[task_type])
        else:
            return 0

    def remove_tasks_from_backlog(self, task_type, count):
        """从积压队列中移除指定类型的任务"""
        if count <= 0:
            return

        if task_type in self.BacklogQueue:
            tasks = self.BacklogQueue[task_type]
            if count >= len(tasks):
                self.BacklogQueue[task_type] = []
            else:
                self.BacklogQueue[task_type] = tasks[count:]

    def get_backlog_tasks(self, task_type):
        """获取指定类型积压队列中的所有任务"""
        if task_type in self.BacklogQueue:
            return self.BacklogQueue[task_type].copy()
        else:
            return []
        
    def peek_task_from_backlog(self, task_type):
        """查看但不移除指定类型积压队列中的第一个任务"""
        if task_type in self.BacklogQueue and len(self.BacklogQueue[task_type]) > 0:
            return self.BacklogQueue[task_type][0]
        else:
            return None
        
    def get_all_backlog_tasks(self):
        """获取所有积压队列中的任务，返回TaskValue2列表"""
        all_tasks = []
        for task_type in self.BacklogQueue:
            if len(self.BacklogQueue[task_type]) > 0:
                # 只需要类型和优先级用于调度决策
                tt = self.TaskTypes[task_type]
                all_tasks.append(TaskValue2(task_type, tt.Priority))
        return all_tasks

    @staticmethod
    def calculate_wkr(mkr, ck):
        """
        计算wkr(t) - 虚拟节点以最小计算频率计算任务所占用的时隙数量
        第k类型任务调度到第r个虚拟节点上计算，所占用的时隙数量
        """
        return math.ceil((mkr * ck / Constants.FM) / Constants.Tslot)

    @staticmethod
    def calculate_scheduling_slots(mkr, ck, node_frequency):
        """计算占用时隙数量"""
        return math.ceil((mkr * ck / node_frequency) / Constants.Tslot)

    @staticmethod
    def calculate_bkr(mkr, ck, node_frequency, is_cache_hit):
        """计算bkr(t) - 调度任务所带来的时隙数量增益"""
        wkr = TaskManager.calculate_wkr(mkr, ck)

        if is_cache_hit:
            bkr = wkr
        else:
            occupied_slots = TaskManager.calculate_scheduling_slots(mkr, ck, node_frequency)
            bkr = wkr - occupied_slots

        return bkr

    def get_all_backlog_count(self):
        """获取所有积压队列中的任务数量"""
        all_count = 0
        for task_type in self.BacklogQueue:
            all_count += len(self.BacklogQueue[task_type])
        return all_count

    def print_task_type_static_info(self):
        """追加打印任务类型的静态信息 到 log.txt文件中"""
        try:
            with open('log.txt', 'a', encoding='utf-8') as f:
                f.write(f'时间戳: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}\n')
                f.write('任务类型静态信息:\n')

                # 直接遍历已知的任务类型数量
                K = Constants.K()
                for i in range(1, K + 1):
                    try:
                        task_type_obj = self.TaskTypes[i]
                        f.write(f'任务类型 {i}: 优先级={task_type_obj.Priority}, '
                               f'计算复杂度={task_type_obj.Ck}, '
                               f'元数据量大小={task_type_obj.MetaK}, '
                               f'产生概率={task_type_obj.PK:.4f}\n')
                    except:
                        f.write(f'任务类型 {i}: 未初始化或访问错误\n')
                f.write('\n')
        except Exception as e:
            print(f"写入日志文件时出错: {e}")
