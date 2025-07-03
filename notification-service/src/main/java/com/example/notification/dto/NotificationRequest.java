package com.example.notification.dto;

/**
 * 通知请求数据传输对象
 */
public class NotificationRequest {
    private String recipient;  // 接收者
    private String type;       // 通知类型 (EMAIL, SMS, PUSH)
    private String title;      // 通知标题
    private String content;    // 通知内容
    
    // Constructors
    public NotificationRequest() {}
    
    public NotificationRequest(String recipient, String type, String title, String content) {
        this.recipient = recipient;
        this.type = type;
        this.title = title;
        this.content = content;
    }
    
    // Getters and Setters
    public String getRecipient() { return recipient; }
    public void setRecipient(String recipient) { this.recipient = recipient; }
    
    public String getType() { return type; }
    public void setType(String type) { this.type = type; }
    
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    
    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }
}
