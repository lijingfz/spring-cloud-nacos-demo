package com.example.order.feign;

import org.springframework.stereotype.Component;

/**
 * 用户服务调用降级处理
 * 当用户服务不可用时的备用方案
 */
@Component
public class UserServiceClientFallback implements UserServiceClient {
    
    @Override
    public UserDto getUserById(Long id) {
        UserDto fallbackUser = new UserDto();
        fallbackUser.setId(id);
        fallbackUser.setUsername("unknown");
        fallbackUser.setEmail("unknown@example.com");
        fallbackUser.setFullName("用户服务暂时不可用");
        return fallbackUser;
    }
    
    @Override
    public ServiceHealthDto getHealth() {
        ServiceHealthDto health = new ServiceHealthDto();
        health.setService("user-service");
        health.setStatus("DOWN");
        health.setTimestamp(System.currentTimeMillis());
        return health;
    }
}
