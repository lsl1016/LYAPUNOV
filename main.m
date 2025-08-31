% 先根据Readme快速了解项目背景，然后阅读整个项目的所有代码，充分理解项目背景和结构，我有哪些类，哪些函数
%
% 参考绘图样式模板.md文件  重新写脚本绘图,（绘图时全部画独立的图，不要画子图，除非我特殊说明，否则参数用默认图）
% 你在完成我的需求时，可能需要在我现在的代码上加一些 变量，新增绘图脚本时请尽可能添加注释
%
% 文件1：（折线图）
% 目的是寻找合适的李雅普诺夫漂移参数VV
% K =20 ,N=20 调度算法使用LyapunovSchedule = 3 ，缓存更像算法使用 Knapsack = 5，横坐标为VV，纵坐标为MEC的时间平均收益

% 文件2：（折线图）
% 第一组：横坐标为时隙（0——Tsolt）,纵坐标分别为MEC时间平均收益、任务积压队列的平均长度
% 图例为：四种调度算法，缓存更新统一使用背包算法，最后一种调度应该是不启用缓存的
%
% 第二组： K =20 ,N=20 ，VV=1
% 横坐标为时隙（0——Tsolt）,纵坐标分别为当前时隙 MEC的时间平均收益、任务积压队列的平均长度、MEC缓存的任务类型总价值，
% 图例为：调度算法使用LyapunovSchedule = 3 + 五种不同的缓存更新算法（FIFO、LRU、LFU、Priority、Knapsack）

% 文件3：（柱状图）
% % 第一组：
% 横坐标取不同的任务类型 k= [10,15,20,25,30], 单时隙的产生任务数量 N=10，totalCacheSize(2000)
% 纵坐标分别为（所有时隙的） MEC的时间平均收益（总收入/总时隙）、任务积压队列的平均长度（所有任务类型的总积压长度/总时隙）、
% 图例为：四种调度算法 + 缓存更新算法使用 Knapsack
% 第二组：
% 横坐标取单时隙产生的不同任务数量 N= [10,15,20,25,30], 任务类型数量 K固定为 15 ，totalCacheSize(2000)
% 纵坐标分别为（所有时隙的） MEC的时间平均收益（总收入/总时隙）、任务积压队列的平均长度（所有任务类型的总积压长度/总时隙）、
% 图例为：四种调度算法 + 缓存更新算法使用 Knapsack
%

% 文件4：（柱状图）
% 第一组：
% 横坐标取不同的任务类型 k= [10,15,20,25,30], 单时隙的产生任务数量 N=10
% 纵坐标分别为（所有时隙的） MEC的时间平均收益（总收入/总时隙）、任务积压队列的平均长度（所有任务类型的总积压长度/总时隙）、MEC缓存的任务类型总价值，
% 所有时隙的缓存命中率（可以借助TaskTypeStat的属性完成，就是 所有时隙所有类型的缓存命中次数求和 / 所有时隙产生的总任务）注：（所有时隙产生的总任务应该 = N*时隙数量）
% 所有时隙的所有任务缓存命中任务总优先级（可以在TaskTypeStat新加一个属性存当前类型任务的命中的总优先级之和）
% 图例为：调度算法使用LyapunovSchedule = 3 + 五种不同的缓存更新算法（FIFO、LRU、LFU、Priority、Knapsack）
% 第二组：
% 横坐标取单时隙产生的不同任务数量 N= [10,15,20,25,30], 任务类型数量 K固定为 15
% 纵坐标分别为（所有时隙的） MEC的时间平均收益（总收入/总时隙）、任务积压队列的平均长度（所有任务类型的总积压长度/总时隙）、MEC缓存的任务类型总价值，
% 所有时隙的缓存命中率（可以借助TaskTypeStat的属性完成，就是 所有时隙所有类型的缓存命中次数求和 / 所有时隙产生的总任务）注：（所有时隙产生的总任务应该 = N*时隙数量）
% 所有时隙的所有任务缓存命中任务总优先级（可以在TaskTypeStat新加一个属性存当前类型任务的命中的总优先级之和）
% 图例为：调度算法使用LyapunovSchedule = 3 + 五种不同的缓存更新算法（FIFO、LRU、LFU、Priority、Knapsack）

% 调度算法实际上是有问题的，我们先不改，之后我单独开一个会话改

%
% function main()
% % main.m - MEC系统仿真主程序
% % 多接入边缘计算系统任务调度与缓存优化仿真
% 
% fprintf('=== MEC系统仿真程序 ===\n');
% fprintf('多接入边缘计算系统任务调度与缓存优化\n\n');
% 
% % 仿真参数设置
% totalTimeSlots = 1000;  % 总时隙数
% 
% fprintf('仿真参数配置:\n');
% fprintf('- 虚拟节点数量: %d\n', Constants.V);
% fprintf('- 任务类型数量: %d\n', Constants.K());
% fprintf('- 每时隙生成任务数: %d\n', Constants.N());
% fprintf('- 总缓存大小: %.1f Mbit\n', Constants.totalCacheSize());
% fprintf('- 总时隙数: %d\n', totalTimeSlots);
% fprintf('- 时隙长度: %.1f 秒\n\n', Constants.Tslot);
% 
% % 运行不同策略的仿真比较
% runComparisonSimulation(totalTimeSlots);
% end
% 
% function runComparisonSimulation(totalTimeSlots)
% % 运行不同策略的比较仿真
% 
% fprintf('=== 开始运行不同策略的比较仿真 ===\n\n');
% 
% % 定义要测试的策略组合
% strategies = {
%     struct('name', '贪心调度+FIFO缓存', 'schedule', Constants.GreedySchedule, 'cache', Constants.FIFO, 'vv', Constants.VV_DEFAULT),
%     struct('name', '贪心调度+LRU缓存', 'schedule', Constants.GreedySchedule, 'cache', Constants.LRU, 'vv', Constants.VV_DEFAULT),
%     struct('name', '贪心调度+背包缓存', 'schedule', Constants.GreedySchedule, 'cache', Constants.Knapsack, 'vv', Constants.VV_DEFAULT),
%     struct('name', '李雅普诺夫调度+FIFO缓存', 'schedule', Constants.LyapunovSchedule, 'cache', Constants.FIFO, 'vv', Constants.VV_DEFAULT),
%     struct('name', '李雅普诺夫调度+LRU缓存', 'schedule', Constants.LyapunovSchedule, 'cache', Constants.LRU, 'vv', Constants.VV_DEFAULT),
%     struct('name', '李雅普诺夫调度+背包缓存', 'schedule', Constants.LyapunovSchedule, 'cache', Constants.Knapsack, 'vv', Constants.VV_DEFAULT),
%     struct('name', '无缓存调度', 'schedule', Constants.NoCacheSchedule, 'cache', Constants.FIFO, 'vv', Constants.VV_DEFAULT)
%     };
% 
% results = {};
% 
% % 运行每种策略的仿真
% for i = 1:length(strategies)
%     strategy = strategies{i};
%     fprintf('--- 运行策略 %d/%d: %s ---\n', i, length(strategies), strategy.name);
% 
%     % 创建仿真器
%     sim = Simulator(totalTimeSlots);
% 
%     % 设置策略
%     sim.setScheduleStrategy(strategy.schedule, strategy.vv);
%     if strategy.schedule ~= Constants.NoCacheSchedule
%         sim.setCacheStrategy(strategy.cache);
%     else
%         % 无缓存策略：禁用缓存
%         sim.MEC.setCacheEnabled(false);
%     end
% 
%     % 运行仿真
%     tic;
%     sim.runSimulation();
%     elapsedTime = toc;
% 
%     % 收集结果
%     stats = sim.getStatistics();
%     result = struct();
%     result.name = strategy.name;
%     result.completionRate = stats.TotalTasksCompleted / stats.TotalTasksGenerated * 100;
%     result.cacheHitRate = 0;
%     if stats.TotalCacheAccess > 0
%         result.cacheHitRate = stats.CacheHitCount / stats.TotalCacheAccess * 100;
%     end
%     result.revenue = sim.MEC.Revenue;
%     result.income = sim.MEC.Income;
%     result.cost = sim.MEC.Cost;
%     result.cacheUtilization = sim.MEC.getCacheUtilization() * 100;
%     result.nodeUtilization = sim.MEC.getNodeUtilization() * 100;
%     result.averageQueueLength = stats.AverageQueueLength;
%     result.elapsedTime = elapsedTime;
% 
%     results{end+1} = result;
% 
%     fprintf('仿真完成，耗时: %.2f 秒\n\n', elapsedTime);
% end
% 
% % 打印比较结果
% printComparisonResults(results);
% 
% % 保存结果到文件
% saveResults(results);
% 
% % 绘制结果图表
% plotResults(results);
% end
% 
% function printComparisonResults(results)
% % 打印比较结果表格
% 
% fprintf('=== 策略比较结果 ===\n');
% fprintf('%-25s | %-8s | %-8s | %-8s | %-8s | %-8s | %-8s\n', ...
%     '策略名称', '完成率%', '命中率%', '收益', '缓存利用%', '节点利用%', '平均队列');
% fprintf('%s\n', repmat('-', 1, 100));
% 
% for i = 1:length(results)
%     result = results{i};
%     fprintf('%-25s | %8.2f | %8.2f | %8.2f | %8.2f | %8.2f | %8.2f\n', ...
%         result.name, result.completionRate, result.cacheHitRate, result.revenue, ...
%         result.cacheUtilization, result.nodeUtilization, result.averageQueueLength);
% end
% 
% fprintf('\n');
% 
% % 找出最优策略
% [maxRevenue, maxRevenueIdx] = max([results{:}].revenue);
% [maxCompletionRate, maxCompletionIdx] = max([results{:}].completionRate);
% [maxCacheHitRate, maxCacheHitIdx] = max([results{:}].cacheHitRate);
% 
% fprintf('=== 最优性能指标 ===\n');
% fprintf('最高收益: %.2f (策略: %s)\n', maxRevenue, results{maxRevenueIdx}.name);
% fprintf('最高完成率: %.2f%% (策略: %s)\n', maxCompletionRate, results{maxCompletionIdx}.name);
% fprintf('最高缓存命中率: %.2f%% (策略: %s)\n', maxCacheHitRate, results{maxCacheHitIdx}.name);
% fprintf('\n');
% end
% 
% function saveResults(results)
% % 保存结果到CSV文件
% 
% try
%     % 创建数据表
%     names = {results{:}}.name;
%     completionRates = [results{:}].completionRate;
%     cacheHitRates = [results{:}].cacheHitRate;
%     revenues = [results{:}].revenue;
%     incomes = [results{:}].income;
%     costs = [results{:}].cost;
%     cacheUtilizations = [results{:}].cacheUtilization;
%     nodeUtilizations = [results{:}].nodeUtilization;
%     averageQueueLengths = [results{:}].averageQueueLength;
%     elapsedTimes = [results{:}].elapsedTime;
% 
%     % 创建表格
%     T = table(names', completionRates', cacheHitRates', revenues', incomes', costs', ...
%         cacheUtilizations', nodeUtilizations', averageQueueLengths', elapsedTimes', ...
%         'VariableNames', {'策略名称', '完成率', '缓存命中率', '收益', '收入', '成本', ...
%         '缓存利用率', '节点利用率', '平均队列长度', '仿真时间'});
% 
%     % 保存到CSV文件
%     filename = sprintf('simulation_results_%s.csv', datestr(now, 'yyyymmdd_HHMMSS'));
%     writetable(T, filename, 'Encoding', 'UTF-8');
%     fprintf('结果已保存到文件: %s\n', filename);
% 
% catch ME
%     fprintf('保存结果文件时出错: %s\n', ME.message);
% end
% end
% 
% function plotResults(results)
% % 绘制结果图表
% 
% try
%     % 提取数据
%     names = {results{:}}.name;
%     completionRates = [results{:}].completionRate;
%     cacheHitRates = [results{:}].cacheHitRate;
%     revenues = [results{:}].revenue;
% 
%     % 创建图形窗口
%     figure('Position', [100, 100, 1200, 800]);
% 
%     % 子图1: 任务完成率
%     subplot(2, 2, 1);
%     bar(completionRates);
%     title('任务完成率对比');
%     ylabel('完成率 (%)');
%     xlabel('策略编号');
%     grid on;
% 
%     % 子图2: 缓存命中率
%     subplot(2, 2, 2);
%     bar(cacheHitRates);
%     title('缓存命中率对比');
%     ylabel('命中率 (%)');
%     xlabel('策略编号');
%     grid on;
% 
%     % 子图3: 系统收益
%     subplot(2, 2, 3);
%     bar(revenues);
%     title('系统收益对比');
%     ylabel('收益');
%     xlabel('策略编号');
%     grid on;
% 
%     % 子图4: 综合性能雷达图
%     subplot(2, 2, 4);
%     % 标准化数据用于雷达图
%     normalizedData = zeros(length(results), 3);
%     normalizedData(:, 1) = completionRates / max(completionRates);
%     normalizedData(:, 2) = cacheHitRates / max(max(cacheHitRates), 1); % 避免除零
%     normalizedData(:, 3) = (revenues - min(revenues)) / (max(revenues) - min(revenues) + eps);
% 
%     % 简单的性能对比图
%     plot(1:length(results), normalizedData(:, 1), 'o-', 'LineWidth', 2, 'DisplayName', '完成率');
%     hold on;
%     plot(1:length(results), normalizedData(:, 2), 's-', 'LineWidth', 2, 'DisplayName', '命中率');
%     plot(1:length(results), normalizedData(:, 3), '^-', 'LineWidth', 2, 'DisplayName', '收益');
%     title('标准化性能对比');
%     ylabel('标准化值');
%     xlabel('策略编号');
%     legend('Location', 'best');
%     grid on;
% 
%     % 保存图形
%     saveas(gcf, sprintf('simulation_plots_%s.png', datestr(now, 'yyyymmdd_HHMMSS')));
%     fprintf('图表已保存\n');
% 
% catch ME
%     fprintf('绘制图表时出错: %s\n', ME.message);
% end
% end
% 
% function runSingleSimulation()
% % 运行单个仿真示例
% 
% fprintf('=== 运行单个仿真示例 ===\n');
% 
% % 创建仿真器
% sim = Simulator(500);
% 
% % 设置策略（李雅普诺夫调度 + 背包缓存）
% sim.setScheduleStrategy(Constants.LyapunovSchedule, Constants.VV_DEFAULT);
% sim.setCacheStrategy(Constants.Knapsack);
% 
% % 运行仿真
% sim.runSimulation();
% end
% 
% % 运行主程序
% if nargin == 0
%     main();
% end
