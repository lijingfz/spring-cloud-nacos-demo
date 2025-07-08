package com.example.order.feign;

/**
 * 服务健康状态 DTO
 */
public class ServiceHealthDto {
    private String service;
    private String version;
    private String status;
    private Long timestamp;
    
    // Constructors, Getters and Setters
    public ServiceHealthDto() {}
    
    public String getService() { return service; }
    public void setService(String service) { this.service = service; }
    
    public String getVersion() { return version; }
    public void setVersion(String version) { this.version = version; }
    
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    
    public Long getTimestamp() { return timestamp; }
    public void setTimestamp(Long timestamp) { this.timestamp = timestamp; }
}
