package com.example.user.service;

import com.example.user.dto.UserDto;
import com.example.user.entity.User;
import com.example.user.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * 用户业务服务类
 */
@Service
@Transactional
public class UserService {
    
    @Autowired
    private UserRepository userRepository;
    
    /**
     * 获取所有用户
     */
    public List<UserDto> getAllUsers() {
        return userRepository.findAll().stream()
                .map(this::convertToDto)
                .collect(Collectors.toList());
    }
    
    /**
     * 根据ID获取用户
     */
    public Optional<UserDto> getUserById(Long id) {
        return userRepository.findById(id)
                .map(this::convertToDto);
    }
    
    /**
     * 根据用户名获取用户
     */
    public Optional<UserDto> getUserByUsername(String username) {
        return userRepository.findByUsername(username)
                .map(this::convertToDto);
    }
    
    /**
     * 创建用户
     */
    public UserDto createUser(String username, String email, String password, String fullName, String phoneNumber) {
        // 检查用户名和邮箱是否已存在
        if (userRepository.existsByUsername(username)) {
            throw new RuntimeException("用户名已存在: " + username);
        }
        if (userRepository.existsByEmail(email)) {
            throw new RuntimeException("邮箱已存在: " + email);
        }
        
        User user = new User(username, email, password, fullName);
        user.setPhoneNumber(phoneNumber);
        User savedUser = userRepository.save(user);
        return convertToDto(savedUser);
    }
    
    /**
     * 更新用户信息
     */
    public Optional<UserDto> updateUser(Long id, String fullName, String phoneNumber) {
        return userRepository.findById(id)
                .map(user -> {
                    if (fullName != null) user.setFullName(fullName);
                    if (phoneNumber != null) user.setPhoneNumber(phoneNumber);
                    return convertToDto(userRepository.save(user));
                });
    }
    
    /**
     * 删除用户
     */
    public boolean deleteUser(Long id) {
        if (userRepository.existsById(id)) {
            userRepository.deleteById(id);
            return true;
        }
        return false;
    }
    
    /**
     * 验证用户登录
     */
    public Optional<UserDto> validateUser(String usernameOrEmail, String password) {
        return userRepository.findByUsernameOrEmail(usernameOrEmail)
                .filter(user -> user.getPassword().equals(password))
                .map(this::convertToDto);
    }
    
    /**
     * 转换实体为DTO
     */
    private UserDto convertToDto(User user) {
        return new UserDto(
                user.getId(),
                user.getUsername(),
                user.getEmail(),
                user.getFullName(),
                user.getPhoneNumber(),
                user.getCreatedAt(),
                user.getUpdatedAt()
        );
    }
}
