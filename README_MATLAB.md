# MEC系统仿真 - MATLAB版本

这是一个基于MATLAB的多接入边缘计算(MEC)系统任务调度与缓存优化仿真程序，从Go语言版本转换而来。

## 系统概述

本仿真系统实现了：
- **MEC虚拟节点**：多个虚拟计算节点，具有不同的计算频率
- **任务管理**：生成、调度和管理不同类型的计算任务
- **缓存系统**：实现多种缓存替换策略（FIFO、LRU、LFU、Priority、Knapsack）
- **调度算法**：包括贪心调度、短期调度、李雅普诺夫优化调度
- **性能统计**：全面的性能指标统计和分析

## 文件结构

### 核心类文件
- `Constants.m` - 系统常量定义
- `Task.m` - 任务实例类
- `TaskType.m` - 任务类型类
- `TaskManager.m` - 任务管理器
- `VirtualNode.m` - 虚拟节点类
- `CacheEntry.m` - 缓存条目类
- `AccessRecord.m` - 访问记录类
- `TaskValue.m` - 任务价值类（背包算法用）
- `MEC.m` - MEC主要功能类
- `MECCache.m` - MEC缓存相关方法扩展

### 调度相关文件
- `LyapunovQueue.m` - 李雅普诺夫队列类
- `LyapunovManager.m` - 李雅普诺夫队列管理器
- `SchedulingResult.m` - 调度结果类
- `TaskValue2.m` - 调度用任务价值类
- `Scheduler.m` - 调度器类

### 仿真相关文件
- `SimulationStats.m` - 仿真统计类
- `TaskTypeStat.m` - 任务类型统计类
- `Simulator.m` - 仿真器主类

### 主程序和测试文件
- `main.m` - 主程序入口
- `test_mec_system.m` - 测试和示例程序

## 运行方法

### 1. 基本使用

在MATLAB命令窗口中运行：

```matlab
% 运行完整的策略比较仿真
main

% 或者运行测试程序
test_mec_system

% 快速演示
quick_demo
```

### 2. 自定义仿真

```matlab
% 创建仿真器
sim = Simulator(1000);  % 1000个时隙

% 设置调度策略
sim.setScheduleStrategy(Constants.LyapunovSchedule, 6.0);

% 设置缓存策略
sim.setCacheStrategy(Constants.Knapsack);

% 运行仿真
sim.runSimulation();

% 获取结果
stats = sim.getStatistics();
```

### 3. 策略配置

#### 调度算法选项：
- `Constants.GreedySchedule` - 贪心调度
- `Constants.ShortTermSchedule` - 短期调度
- `Constants.LyapunovSchedule` - 李雅普诺夫调度（推荐）
- `Constants.NoCacheSchedule` - 无缓存调度

#### 缓存策略选项：
- `Constants.FIFO` - 先进先出
- `Constants.LFU` - 最少使用频率
- `Constants.LRU` - 最近最少使用
- `Constants.Priority` - 基于优先级
- `Constants.Knapsack` - 基于01背包算法（推荐）

## 系统参数配置

主要参数在`Constants.m`中定义：

```matlab
% 系统配置
V = 5;          % 虚拟节点数量
N = 25;         % 每时隙生成任务数
K = 20;         % 任务类型总数
Tslot = 0.5;    % 时隙长度(秒)
TOTAL_CACHE_SIZE = 1500.0;  % 总缓存大小(Mbit)

% 性能参数
WHIT = 3.0;     % 缓存命中收益系数
WCOM = 1.2;     % 计算收益系数
AFIE = 0.02;    % 能耗电价
VV_DEFAULT = 6.0; % 李雅普诺夫参数
```

## 核心算法

### 1. 李雅普诺夫优化调度

实现基于李雅普诺夫稳定性理论的优化调度算法：
- 目标函数：最大化 `V*(收益-成本) - Q*服务增益`
- 使用匈牙利算法求解任务-节点最优匹配
- 平衡系统稳定性和性能优化

### 2. 01背包缓存策略

使用动态规划实现的01背包算法优化缓存内容：
- 价值函数：`访问频率 × 任务优先级`
- 权重：任务元数据大小
- 约束：总缓存容量限制

### 3. 任务调度流程

每个时隙的处理流程：
1. 生成新任务
2. 移除过期任务
3. 检查缓存命中和计算状态
4. 执行调度算法
5. 更新虚拟节点状态
6. 更新缓存内容
7. 更新李雅普诺夫队列
8. 计算收益

## 性能指标

系统统计以下性能指标：
- **任务完成率**：完成任务数 / 生成任务数
- **缓存命中率**：缓存命中次数 / 总访问次数
- **系统收益**：总收入 - 总成本
- **资源利用率**：缓存利用率、节点利用率
- **平均队列长度**：李雅普诺夫队列平均长度

## 结果输出

程序会生成：
- 控制台统计输出
- CSV格式的详细结果文件
- 性能对比图表（PNG格式）

## 依赖要求

- MATLAB R2016b或更高版本
- 推荐：Optimization Toolbox（用于匈牙利算法，无此工具箱会自动使用备选方案）

## 注意事项

1. **内存使用**：大规模仿真（时隙数>5000）可能消耗较多内存
2. **计算时间**：李雅普诺夫调度比贪心调度耗时更长
3. **参数调优**：可根据具体应用场景调整Constants.m中的参数
4. **扩展性**：可以轻松添加新的缓存策略和调度算法

## 示例输出

```
=== 仿真统计结果 ===
总时隙数: 1000
总生成任务数: 24987
总完成任务数: 23156
总丢弃任务数: 1831
任务完成率: 92.67%
缓存命中次数: 15432
总缓存访问次数: 24987
缓存命中率: 61.79%
缓存利用率: 87.33%
节点利用率: 78.40%
最终收益: 1234.56
```

## 技术支持

如有问题或建议，请检查：
1. MATLAB版本兼容性
2. 文件路径设置
3. 参数配置合理性

本MATLAB版本保持了Go原版的核心算法和功能，同时针对MATLAB环境进行了优化。
