package com.example.gateway;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.gateway.route.RouteLocator;
import org.springframework.cloud.gateway.route.builder.RouteLocatorBuilder;
import org.springframework.context.annotation.Bean;

/**
 * API 网关服务
 * 提供路由、负载均衡、熔断等功能
 */
@SpringBootApplication
public class GatewayApplication {

    public static void main(String[] args) {
        SpringApplication.run(GatewayApplication.class, args);
    }

    /**
     * 配置路由规则
     */
    @Bean
    public RouteLocator customRouteLocator(RouteLocatorBuilder builder) {
        return builder.routes()
                // 用户服务路由
                .route("user-service", r -> r.path("/api/users/**")
                        .uri("lb://user-service"))
                // 订单服务路由
                .route("order-service", r -> r.path("/api/orders/**")
                        .uri("lb://order-service"))
                // 通知服务路由
                .route("notification-service", r -> r.path("/api/notifications/**")
                        .uri("lb://notification-service"))
                // 健康检查路由
                .route("user-health", r -> r.path("/health/users")
                        .uri("lb://user-service/actuator/health"))
                .route("order-health", r -> r.path("/health/orders")
                        .uri("lb://order-service/actuator/health"))
                .route("notification-health", r -> r.path("/health/notifications")
                        .uri("lb://notification-service/actuator/health"))
                .build();
    }
}
