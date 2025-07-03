package com.example.order.entity;

/**
 * 订单状态枚举
 */
public enum OrderStatus {
    PENDING,    // 待处理
    CONFIRMED,  // 已确认
    SHIPPED,    // 已发货
    DELIVERED,  // 已送达
    CANCELLED   // 已取消
}
