package com.example.order.repository;

import com.example.order.entity.Order;
import com.example.order.entity.OrderStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

/**
 * 订单数据访问层
 */
@Repository
public interface OrderRepository extends JpaRepository<Order, Long> {
    
    /**
     * 根据订单号查找订单
     */
    Optional<Order> findByOrderNumber(String orderNumber);
    
    /**
     * 根据用户ID查找订单列表
     */
    List<Order> findByUserId(Long userId);
    
    /**
     * 根据订单状态查找订单
     */
    List<Order> findByStatus(OrderStatus status);
    
    /**
     * 根据用户ID和状态查找订单
     */
    List<Order> findByUserIdAndStatus(Long userId, OrderStatus status);
    
    /**
     * 计算总金额
     */
    @Query("SELECT SUM(o.totalAmount) FROM Order o")
    BigDecimal sumTotalAmount();
    
    /**
     * 根据用户ID计算总金额
     */
    @Query("SELECT SUM(o.totalAmount) FROM Order o WHERE o.userId = ?1")
    BigDecimal sumTotalAmountByUserId(Long userId);
}
