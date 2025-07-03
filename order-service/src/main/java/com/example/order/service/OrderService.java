package com.example.order.service;

import com.example.order.entity.Order;
import com.example.order.entity.OrderStatus;
import com.example.order.feign.UserServiceClient;
import com.example.order.repository.OrderRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Optional;

/**
 * 订单业务服务类
 */
@Service
@Transactional
public class OrderService {
    
    @Autowired
    private OrderRepository orderRepository;
    
    @Autowired
    private UserServiceClient userServiceClient;
    
    /**
     * 获取所有订单
     */
    public List<Order> getAllOrders() {
        return orderRepository.findAll();
    }
    
    /**
     * 根据ID获取订单
     */
    public Optional<Order> getOrderById(Long id) {
        return orderRepository.findById(id);
    }
    
    /**
     * 根据用户ID获取订单列表
     */
    public List<Order> getOrdersByUserId(Long userId) {
        return orderRepository.findByUserId(userId);
    }
    
    /**
     * 根据订单号获取订单
     */
    public Optional<Order> getOrderByOrderNumber(String orderNumber) {
        return orderRepository.findByOrderNumber(orderNumber);
    }
    
    /**
     * 创建订单
     */
    public Order createOrder(Long userId, String productName, Integer quantity, BigDecimal unitPrice) {
        // 验证用户是否存在（通过 Feign 调用用户服务）
        try {
            var user = userServiceClient.getUserById(userId);
            if (user == null || "unknown".equals(user.getUsername())) {
                throw new RuntimeException("用户不存在或用户服务不可用: " + userId);
            }
        } catch (Exception e) {
            // 如果用户服务调用失败，记录日志但继续处理（演示容错机制）
            System.out.println("警告：无法验证用户信息，用户服务可能不可用: " + e.getMessage());
        }
        
        String orderNumber = generateOrderNumber();
        Order order = new Order(orderNumber, userId, productName, quantity, unitPrice);
        return orderRepository.save(order);
    }
    
    /**
     * 更新订单状态
     */
    public Optional<Order> updateOrderStatus(Long id, String status) {
        return orderRepository.findById(id)
                .map(order -> {
                    try {
                        order.setStatus(OrderStatus.valueOf(status.toUpperCase()));
                        return orderRepository.save(order);
                    } catch (IllegalArgumentException e) {
                        throw new RuntimeException("无效的订单状态: " + status);
                    }
                });
    }
    
    /**
     * 取消订单
     */
    public Optional<Order> cancelOrder(Long id) {
        return orderRepository.findById(id)
                .map(order -> {
                    order.setStatus(OrderStatus.CANCELLED);
                    return orderRepository.save(order);
                });
    }
    
    /**
     * 删除订单
     */
    public boolean deleteOrder(Long id) {
        if (orderRepository.existsById(id)) {
            orderRepository.deleteById(id);
            return true;
        }
        return false;
    }
    
    /**
     * 获取订单统计信息
     */
    public OrderStatistics getOrderStatistics() {
        long totalOrders = orderRepository.count();
        BigDecimal totalAmount = orderRepository.sumTotalAmount();
        if (totalAmount == null) totalAmount = BigDecimal.ZERO;
        
        return new OrderStatistics(totalOrders, totalAmount);
    }
    
    /**
     * 生成订单号
     */
    private String generateOrderNumber() {
        String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss"));
        String random = String.valueOf((int)(Math.random() * 1000));
        return "ORD" + timestamp + String.format("%03d", Integer.parseInt(random));
    }
    
    /**
     * 订单统计信息类
     */
    public static class OrderStatistics {
        private long totalOrders;
        private BigDecimal totalAmount;
        
        public OrderStatistics(long totalOrders, BigDecimal totalAmount) {
            this.totalOrders = totalOrders;
            this.totalAmount = totalAmount;
        }
        
        public long getTotalOrders() { return totalOrders; }
        public BigDecimal getTotalAmount() { return totalAmount; }
    }
}
