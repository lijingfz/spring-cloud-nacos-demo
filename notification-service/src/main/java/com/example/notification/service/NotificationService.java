package com.example.notification.service;

import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

/**
 * 通知业务服务类
 */
@Service
public class NotificationService {
    
    // 模拟通知历史存储（生产环境应使用数据库）
    private final Map<String, List<Map<String, Object>>> notificationHistory = new ConcurrentHashMap<>();
    
    // 统计计数器
    private final AtomicLong totalNotifications = new AtomicLong(0);
    private final AtomicLong successfulNotifications = new AtomicLong(0);
    private final AtomicLong failedNotifications = new AtomicLong(0);
    
    /**
     * 发送单个通知
     */
    public boolean sendNotification(String recipient, String type, String title, String content) {
        try {
            // 模拟通知发送逻辑
            boolean success = simulateNotificationSending(recipient, type);
            
            // 记录通知历史
            recordNotificationHistory(recipient, type, title, content, success);
            
            // 更新统计
            totalNotifications.incrementAndGet();
            if (success) {
                successfulNotifications.incrementAndGet();
            } else {
                failedNotifications.incrementAndGet();
            }
            
            return success;
        } catch (Exception e) {
            failedNotifications.incrementAndGet();
            return false;
        }
    }
    
    /**
     * 批量发送通知
     */
    public int sendBatchNotifications(List<String> recipients, String type, String title, String content) {
        int successCount = 0;
        
        for (String recipient : recipients) {
            if (sendNotification(recipient, type, title, content)) {
                successCount++;
            }
        }
        
        return successCount;
    }
    
    /**
     * 获取通知历史
     */
    public List<Map<String, Object>> getNotificationHistory(String recipient) {
        return notificationHistory.getOrDefault(recipient, new ArrayList<>());
    }
    
    /**
     * 获取通知统计信息
     */
    public Map<String, Object> getNotificationStatistics() {
        Map<String, Object> statistics = new HashMap<>();
        statistics.put("totalNotifications", totalNotifications.get());
        statistics.put("successfulNotifications", successfulNotifications.get());
        statistics.put("failedNotifications", failedNotifications.get());
        statistics.put("successRate", calculateSuccessRate());
        statistics.put("timestamp", System.currentTimeMillis());
        
        return statistics;
    }
    
    /**
     * 模拟通知发送
     */
    private boolean simulateNotificationSending(String recipient, String type) {
        // 模拟网络延迟
        try {
            Thread.sleep(100 + (int)(Math.random() * 200));
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        
        // 模拟发送成功率（90%成功率）
        return Math.random() > 0.1;
    }
    
    /**
     * 记录通知历史
     */
    private void recordNotificationHistory(String recipient, String type, String title, String content, boolean success) {
        Map<String, Object> record = new HashMap<>();
        record.put("type", type);
        record.put("title", title);
        record.put("content", content);
        record.put("success", success);
        record.put("timestamp", LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
        
        notificationHistory.computeIfAbsent(recipient, k -> new ArrayList<>()).add(record);
        
        // 限制历史记录数量（最多保留100条）
        List<Map<String, Object>> history = notificationHistory.get(recipient);
        if (history.size() > 100) {
            history.remove(0);
        }
    }
    
    /**
     * 计算成功率
     */
    private double calculateSuccessRate() {
        long total = totalNotifications.get();
        if (total == 0) {
            return 0.0;
        }
        return (double) successfulNotifications.get() / total * 100;
    }
}
