"""
日志工具类
用于向log.txt文件追加打印日志信息
"""

import os
from datetime import datetime

class Logger:
    """Logger 日志记录工具类"""
    
    def __init__(self, log_file="./LYAPUNOV/log.txt", enable_log=True):
        """
        构造函数
        
        参数:
        log_file: 日志文件名，默认为"log.txt"
        enable_log: 是否启用日志记录，默认为True
        """
        self.log_file = log_file
        self.Enable_Log = enable_log
        
    def set_enable_log(self, enable):
        """
        设置是否启用日志记录
        
        参数:
        enable: True表示启用，False表示禁用
        """
        self.Enable_Log = enable
    
    def log(self, message, level="INFO"):
        """
        记录日志信息
        
        参数:
        message: 要记录的消息
        level: 日志级别，如INFO, DEBUG, WARNING, ERROR
        """
        # 如果日志记录被禁用，直接返回
        if not self.Enable_Log:
            return
            
        try:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            log_entry = f"[{timestamp}] [{level}] {message}\n"
            
            with open(self.log_file, 'a', encoding='utf-8') as f:
                f.write(log_entry)
        except Exception as e:
            print(f"写入日志文件时出错: {e}")
    
    def info(self, message):
        """记录INFO级别日志"""
        self.log(message, "INFO")
    
    def debug(self, message):
        """记录DEBUG级别日志"""
        self.log(message, "DEBUG")
    
    def warning(self, message):
        """记录WARNING级别日志"""
        self.log(message, "WARNING")
    
    def error(self, message):
        """记录ERROR级别日志"""
        self.log(message, "ERROR")
    
    def separator(self, char="=", length=50):
        """添加分隔线"""
        # 如果日志记录被禁用，直接返回
        if not self.Enable_Log:
            return
        separator_line = char * length
        self.log(separator_line, "")
    
    def clear_log(self):
        """清空日志文件"""
        # 如果日志记录被禁用，直接返回
        if not self.Enable_Log:
            return
        try:
            with open(self.log_file, 'w', encoding='utf-8') as f:
                f.write("")
            self.info("日志文件已清空")
        except Exception as e:
            print(f"清空日志文件时出错: {e}")
    
    def log_revenue_details(self, time_slot, cache_income, compute_income, cache_cost, compute_cost, total_profit):
        """
        记录收益详细信息
        
        参数:
        time_slot: 当前时隙
        cache_income: 缓存收入
        compute_income: 计算收入  
        cache_cost: 缓存成本
        compute_cost: 计算成本
        total_profit: 总利润
        """
        # 如果日志记录被禁用，直接返回
        if not self.Enable_Log:
            return
            
        self.separator("-", 60)
        self.info(f"时隙 {time_slot} 收益详情:")
        self.info(f"  缓存收入: {cache_income:.6f}")
        self.info(f"  计算收入: {compute_income:.6f}")
        self.info(f"  总收入: {cache_income + compute_income:.6f}")
        self.info(f"  缓存成本: {cache_cost:.6f}")
        self.info(f"  计算成本: {compute_cost:.6f}")
        self.info(f"  总成本: {cache_cost + compute_cost:.6f}")
        self.info(f"  净利润: {total_profit:.6f}")
        self.separator("-", 60)

# 创建全局日志实例（默认禁用日志以提高性能，可手动启用）
logger = Logger(enable_log=False)
