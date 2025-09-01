# MEC系统仿真 - Python版本

这是一个基于Python的多接入边缘计算(MEC)系统任务调度与缓存优化仿真程序，从MATLAB版本转换而来，保留了所有原始逻辑和注释。

## 系统概述

本仿真系统实现了：
- **MEC虚拟节点**：多个虚拟计算节点，具有不同的计算频率
- **任务管理**：生成、调度和管理不同类型的计算任务
- **缓存系统**：实现多种缓存替换策略（FIFO、LRU、LFU、Priority、Knapsack）
- **调度算法**：包括贪心调度、短期调度、李雅普诺夫优化调度
- **性能统计**：全面的性能指标统计和分析

## 文件结构

### 核心类文件
- `constants.py` - 系统常量定义
- `task_classes.py` - 任务相关类（Task、TaskType、TaskValue等）
- `cache_classes.py` - 缓存相关类（CacheEntry、AccessRecord）
- `virtual_node.py` - 虚拟节点类
- `task_manager.py` - 任务管理器
- `mec.py` - MEC主要功能类
- `lyapunov_classes.py` - 李雅普诺夫队列相关类
- `scheduler.py` - 调度器类
- `stats_classes.py` - 统计相关类
- `simulator.py` - 仿真器主类

### 绘图和可视化文件
- `plot1_lyapunov_vv_optimization.py` - 李雅普诺夫参数VV优化折线图
- `plot2_timeseries_comparison.py` - 时序性能对比折线图
- `plot3_parameter_comparison.py` - 参数对比柱状图
- `plot4_cache_strategy_comparison.py` - 缓存策略性能对比柱状图
- `plotting.py` - 统一绘图模块
- `plotting_example.py` - 绘图模块使用示例

### 测试和工具文件
- `test_mec_system.py` - 测试和示例程序
- `__init__.py` - 包初始化文件
- `requirements.txt` - 依赖包列表
- `README.md` - 本文档

## 安装和运行

### 1. 环境要求

- Python 3.7+
- NumPy 1.19+
- SciPy 1.5+

### 2. 安装依赖

```bash
pip install -r requirements.txt
```

### 3. 基本使用

```python
from LYAPUNOV import Simulator, Constants

# 创建仿真器
sim = Simulator(1000)  # 1000个时隙

# 设置调度策略
sim.set_schedule_strategy(Constants.LyapunovSchedule, 6.0)

# 设置缓存策略
sim.set_cache_strategy(Constants.Knapsack)

# 运行仿真
sim.run_simulation()

# 获取结果
stats = sim.get_statistics()
```

### 4. 运行测试

```python
# 方法1：作为模块运行
from LYAPUNOV.test_mec_system import test_mec_system, quick_demo

# 运行完整测试
test_mec_system()

# 运行快速演示
quick_demo()
```

```python
# 方法2：直接运行测试文件
python -m LYAPUNOV.test_mec_system
```

### 5. 运行绘图实验

```python
# 导入绘图模块
from LYAPUNOV.plotting import PlottingModule

# 创建绘图模块实例
plotting = PlottingModule()

# 运行所有绘图实验
plotting.run_all_plots()

# 或运行单个实验
plotting.run_plot1()  # 李雅普诺夫参数VV优化
plotting.run_plot2()  # 时序性能对比
plotting.run_plot3()  # 参数对比
plotting.run_plot4()  # 缓存策略对比
```

```python
# 直接运行绘图模块
python -m LYAPUNOV.plotting
```

## 策略配置

### 调度算法选项：
- `Constants.GreedySchedule` - 贪心调度
- `Constants.ShortTermSchedule` - 短期调度
- `Constants.LyapunovSchedule` - 李雅普诺夫调度（推荐）
- `Constants.NoCacheSchedule` - 无缓存调度

### 缓存策略选项：
- `Constants.FIFO` - 先进先出
- `Constants.LFU` - 最少使用频率
- `Constants.LRU` - 最近最少使用
- `Constants.Priority` - 基于优先级
- `Constants.Knapsack` - 基于01背包算法（推荐）

## 系统参数配置

主要参数在`Constants`类中定义：

```python
# 系统配置
V = 10          # 虚拟节点数量
N() = 40        # 每时隙生成任务数（可配置）
K() = 40        # 任务类型总数（可配置）
Tslot = 1       # 时隙长度(秒)
total_cache_size() = 1000  # 总缓存大小(Mbit)（可配置）

# 性能参数
WHIT = 3.0      # 缓存命中收益系数
WCOM = 1.2      # 计算收益系数
AFIE = 0.02     # 能耗电价
VV_DEFAULT = 6.0 # 李雅普诺夫参数
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

## 与MATLAB版本的差异

1. **语法转换**：从MATLAB语法转换为Python语法
2. **数据结构**：使用Python字典替代MATLAB的containers.Map
3. **数组索引**：从1基索引转换为0基索引（内部实现）
4. **依赖库**：使用NumPy和SciPy替代MATLAB内置函数
5. **面向对象**：保持了MATLAB版本的面向对象设计

## 绘图实验说明

Python版本包含完整的绘图功能，从MATLAB版本转换而来：

### Plot1 - 李雅普诺夫参数VV优化
- **目的**：寻找合适的李雅普诺夫漂移参数VV
- **参数**：K=20, N=20, 李雅普诺夫调度+背包缓存
- **输出**：VV参数对系统收益影响的折线图

### Plot2 - 时序性能对比
- **第一组**：四种调度算法时序对比（统一使用背包缓存）
- **第二组**：五种缓存算法时序对比（使用李雅普诺夫调度）
- **输出**：收益、积压队列长度、缓存价值随时间变化

### Plot3 - 参数对比
- **第一组**：不同任务类型数量K的性能对比
- **第二组**：不同任务生成数量N的性能对比
- **输出**：收益、积压队列长度、任务丢弃率的柱状图

### Plot4 - 缓存策略对比
- **第一组**：不同K值下各缓存策略性能对比
- **第二组**：不同N值下各缓存策略性能对比
- **输出**：收益、积压队列、缓存价值、命中率、命中优先级

## 扩展功能

相比MATLAB版本，Python版本具有以下优势：
- 更好的包管理和依赖处理
- 丰富的数据分析和可视化库（matplotlib, seaborn）
- 更容易集成到现有的Python生态系统
- 支持更灵活的部署方式
- 完整的绘图和可视化功能

## 注意事项

1. **内存使用**：大规模仿真（时隙数>5000）可能消耗较多内存
2. **计算时间**：李雅普诺夫调度比贪心调度耗时更长
3. **参数调优**：可根据具体应用场景调整Constants中的参数
4. **扩展性**：可以轻松添加新的缓存策略和调度算法

## 技术支持

如有问题或建议，请检查：
1. Python版本兼容性（建议3.7+）
2. 依赖包版本
3. 参数配置合理性

本Python版本完全保持了MATLAB原版的核心算法和功能，同时针对Python环境进行了优化。
