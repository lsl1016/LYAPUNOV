"""
统一的绘图模块 - 包含所有绘图功能的统一入口
从MATLAB版本转换而来，保留所有原始逻辑和注释
"""

# 配置中文字体支持
try:
    from .font_config import setup_chinese_font
except ImportError:
    from font_config import setup_chinese_font

# 设置中文字体
setup_chinese_font()

from .plot1_lyapunov_vv_optimization import plot1_lyapunov_vv_optimization
from .plot2_timeseries_comparison import plot2_timeseries_comparison
from .plot3_parameter_comparison import plot3_parameter_comparison
from .plot4_cache_strategy_comparison import plot4_cache_strategy_comparison


class PlottingModule:
    """统一的绘图模块类"""
    
    @staticmethod
    def run_all_plots():
        """运行所有绘图实验"""
        print('=== 开始运行所有绘图实验 ===\n')
        
        print('【1/4】李雅普诺夫参数VV优化实验')
        plot1_lyapunov_vv_optimization()
        print('\n' + '='*60 + '\n')
        
        print('【2/4】时序性能对比实验')
        plot2_timeseries_comparison()
        print('\n' + '='*60 + '\n')
        
        print('【3/4】参数对比实验')
        plot3_parameter_comparison()
        print('\n' + '='*60 + '\n')
        
        print('【4/4】缓存策略对比实验')
        plot4_cache_strategy_comparison()
        print('\n' + '='*60 + '\n')
        
        print('=== 所有绘图实验完成 ===')
    
    @staticmethod
    def run_plot1():
        """运行李雅普诺夫参数VV优化实验"""
        return plot1_lyapunov_vv_optimization()
    
    @staticmethod
    def run_plot2():
        """运行时序性能对比实验"""
        plot2_timeseries_comparison()
    
    @staticmethod
    def run_plot3():
        """运行参数对比实验"""
        plot3_parameter_comparison()
    
    @staticmethod
    def run_plot4():
        """运行缓存策略对比实验"""
        plot4_cache_strategy_comparison()


def main():
    """主函数示例"""
    plotting = PlottingModule()
    
    # 可以选择运行单个实验或所有实验
    # plotting.run_plot1()  # 运行单个实验
    plotting.run_all_plots()  # 运行所有实验


if __name__ == "__main__":
    main()
