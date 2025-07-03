package com.example.gateway;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import reactor.core.publisher.Mono;

import java.util.HashMap;
import java.util.Map;

/**
 * 熔断降级处理控制器
 */
@RestController
@RequestMapping("/fallback")
public class FallbackController {

    @GetMapping("/users")
    public Mono<Map<String, Object>> userFallback() {
        Map<String, Object> response = new HashMap<>();
        response.put("message", "用户服务暂时不可用，请稍后重试");
        response.put("status", "fallback");
        response.put("service", "user-service");
        return Mono.just(response);
    }

    @GetMapping("/orders")
    public Mono<Map<String, Object>> orderFallback() {
        Map<String, Object> response = new HashMap<>();
        response.put("message", "订单服务暂时不可用，请稍后重试");
        response.put("status", "fallback");
        response.put("service", "order-service");
        return Mono.just(response);
    }
}
