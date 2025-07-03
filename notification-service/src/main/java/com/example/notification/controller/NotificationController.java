package com.example.notification.controller;

import com.example.notification.dto.NotificationRequest;
import com.example.notification.service.NotificationService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 通知控制器
 * 提供通知管理的REST API
 */
@RestController
@RequestMapping("/api/notifications")
public class NotificationController {
    
    @Autowired
    private NotificationService notificationService;
    
    @Value("${app.name:通知服务}")
    private String appName;
    
    @Value("${app.version:1.0.0}")
    private String appVersion;
    
    /**
     * 服务健康检查
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        Map<String, Object> response = new HashMap<>();
        response.put("service", appName);
        response.put("version", appVersion);
        response.put("status", "UP");
        response.put("timestamp", System.currentTimeMillis());
        return ResponseEntity.ok(response);
    }
    
    /**
     * 发送通知
     */
    @PostMapping("/send")
    public ResponseEntity<Map<String, Object>> sendNotification(@RequestBody NotificationRequest request) {
        boolean success = notificationService.sendNotification(
                request.getRecipient(),
                request.getType(),
                request.getTitle(),
                request.getContent()
        );
        
        Map<String, Object> response = new HashMap<>();
        response.put("success", success);
        response.put("message", success ? "通知发送成功" : "通知发送失败");
        response.put("timestamp", System.currentTimeMillis());
        
        return ResponseEntity.ok(response);
    }
    
    /**
     * 批量发送通知
     */
    @PostMapping("/send/batch")
    public ResponseEntity<Map<String, Object>> sendBatchNotifications(@RequestBody BatchNotificationRequest request) {
        int successCount = notificationService.sendBatchNotifications(
                request.getRecipients(),
                request.getType(),
                request.getTitle(),
                request.getContent()
        );
        
        Map<String, Object> response = new HashMap<>();
        response.put("totalRecipients", request.getRecipients().size());
        response.put("successCount", successCount);
        response.put("failureCount", request.getRecipients().size() - successCount);
        response.put("timestamp", System.currentTimeMillis());
        
        return ResponseEntity.ok(response);
    }
    
    /**
     * 获取通知历史
     */
    @GetMapping("/history/{recipient}")
    public ResponseEntity<List<Map<String, Object>>> getNotificationHistory(@PathVariable String recipient) {
        List<Map<String, Object>> history = notificationService.getNotificationHistory(recipient);
        return ResponseEntity.ok(history);
    }
    
    /**
     * 获取通知统计
     */
    @GetMapping("/statistics")
    public ResponseEntity<Map<String, Object>> getNotificationStatistics() {
        Map<String, Object> statistics = notificationService.getNotificationStatistics();
        return ResponseEntity.ok(statistics);
    }
    
    // 内部类定义请求对象
    public static class BatchNotificationRequest {
        private List<String> recipients;
        private String type;
        private String title;
        private String content;
        
        // Getters and Setters
        public List<String> getRecipients() { return recipients; }
        public void setRecipients(List<String> recipients) { this.recipients = recipients; }
        
        public String getType() { return type; }
        public void setType(String type) { this.type = type; }
        
        public String getTitle() { return title; }
        public void setTitle(String title) { this.title = title; }
        
        public String getContent() { return content; }
        public void setContent(String content) { this.content = content; }
    }
}
