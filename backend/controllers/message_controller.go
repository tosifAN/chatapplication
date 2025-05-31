package controllers

import (
	"fmt"
	"log"
	"net/http"
	"time"

	"backend/models"
	"backend/mqtt"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

// MessageController handles message-related requests
type MessageController struct {
	db         *gorm.DB
	mqttClient *mqtt.MQTTClient
}

// NewMessageController creates a new message controller
func NewMessageController(db *gorm.DB, mqttClient *mqtt.MQTTClient) *MessageController {
	return &MessageController{db: db, mqttClient: mqttClient}
}

// SendDirectMessageRequest represents the request body for sending a direct message
type SendDirectMessageRequest struct {
	ReceiverID string `json:"receiver_id" binding:"required"`
	Content    string `json:"content" binding:"required"`
	Type       string `json:"type" binding:"required"`
}

// SendGroupMessageRequest represents the request body for sending a group message
type SendGroupMessageRequest struct {
	GroupID string `json:"group_id" binding:"required"`
	Content string `json:"content" binding:"required"`
	Type    string `json:"type" binding:"required"`
}

// GetDirectMessages gets direct messages between two users
func (mc *MessageController) GetDirectMessages(c *gin.Context) {
	userID := c.Param("userId")
	otherUserID := c.Param("otherUserId")

	// Get pagination parameters
	limit := 50
	offset := 0
	if limitParam := c.Query("limit"); limitParam != "" {
		if _, err := fmt.Sscanf(limitParam, "%d", &limit); err != nil {
			limit = 50
		}
	}
	if offsetParam := c.Query("offset"); offsetParam != "" {
		if _, err := fmt.Sscanf(offsetParam, "%d", &offset); err != nil {
			offset = 0
		}
	}

	// Get the authenticated user ID from the context
	authUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// Check if the authenticated user is one of the participants
	if authUserID != userID && authUserID != otherUserID {
		c.JSON(http.StatusForbidden, gin.H{"error": "You can only access your own messages"})
		return
	}

	// Get messages between the two users
	var messages []models.Message
	result := mc.db.Preload("Sender").Where(
		"(sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)",
		userID, otherUserID, otherUserID, userID,
	).Order("timestamp DESC").Limit(limit).Offset(offset).Find(&messages)

	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get messages"})
		return
	}

	c.JSON(http.StatusOK, messages)
}

// SendDirectMessage sends a direct message to another user
func (mc *MessageController) SendDirectMessage(c *gin.Context) {
	// Get the authenticated user ID from the context
	senderID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// Parse request body
	var req SendDirectMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if receiver exists
	var receiver models.User
	result := mc.db.First(&receiver, "id = ?", req.ReceiverID)
	if result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Receiver not found"})
		return
	}

	// Create message
	now := time.Now()
	messageID := uuid.New().String()
	message := models.Message{
		ID:         messageID,
		SenderID:   senderID.(string),
		ReceiverID: &req.ReceiverID,
		Content:    req.Content,
		Type:       models.MessageType(req.Type),
		Timestamp:  now,
		CreatedAt:  now,
		UpdatedAt:  now,
	}

	// Save message to database
	result = mc.db.Create(&message)
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save message"})
		return
	}

	// Publish message to MQTT
	err := mc.mqttClient.PublishDirectMessage(&message)
	if err != nil {
		// Log error but don't fail the request
		log.Printf("Failed to publish message to MQTT: %v", err)
	}

	// Load sender details
	mc.db.First(&message.Sender, "id = ?", message.SenderID)

	c.JSON(http.StatusCreated, message)
}

// GetGroupMessages gets messages for a group
func (mc *MessageController) GetGroupMessages(c *gin.Context) {
	groupID := c.Param("groupId")

	// Get pagination parameters
	limit := 50
	offset := 0
	if limitParam := c.Query("limit"); limitParam != "" {
		if _, err := fmt.Sscanf(limitParam, "%d", &limit); err != nil {
			limit = 50
		}
	}
	if offsetParam := c.Query("offset"); offsetParam != "" {
		if _, err := fmt.Sscanf(offsetParam, "%d", &offset); err != nil {
			offset = 0
		}
	}

	// Get the authenticated user ID from the context
	authUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// Check if the group exists
	var group models.Group
	result := mc.db.First(&group, "id = ?", groupID)
	if result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Group not found"})
		return
	}

	// Check if the user is a member of the group
	var groupUser models.GroupUser
	result = mc.db.Where("group_id = ? AND user_id = ?", groupID, authUserID).First(&groupUser)
	if result.Error != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": "You are not a member of this group"})
		return
	}

	// Get messages for the group
	var messages []models.Message
	result = mc.db.Preload("Sender").Where("group_id = ?", groupID).Order("timestamp DESC").Limit(limit).Offset(offset).Find(&messages)
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get messages"})
		return
	}

	c.JSON(http.StatusOK, messages)
}

// SendGroupMessage sends a message to a group
func (mc *MessageController) SendGroupMessage(c *gin.Context) {
	// Get the authenticated user ID from the context
	senderID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// Parse request body
	var req SendGroupMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if the group exists
	var group models.Group
	result := mc.db.First(&group, "id = ?", req.GroupID)
	if result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Group not found"})
		return
	}

	// Check if the user is a member of the group
	var groupUser models.GroupUser
	result = mc.db.Where("group_id = ? AND user_id = ?", req.GroupID, senderID).First(&groupUser)
	if result.Error != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": "You are not a member of this group"})
		return
	}

	// Create message
	now := time.Now()
	messageID := uuid.New().String()
	message := models.Message{
		ID:        messageID,
		SenderID:  senderID.(string),
		GroupID:   &req.GroupID,
		Content:   req.Content,
		Type:      models.MessageType(req.Type),
		Timestamp: now,
		CreatedAt: now,
		UpdatedAt: now,
	}

	// Save message to database
	result = mc.db.Create(&message)
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save message"})
		return
	}

	// Publish message to MQTT
	err := mc.mqttClient.PublishGroupMessage(&message)
	if err != nil {
		// Log error but don't fail the request
		log.Printf("Failed to publish message to MQTT: %v", err)
	}

	// Load sender details
	mc.db.First(&message.Sender, "id = ?", message.SenderID)

	c.JSON(http.StatusCreated, message)
}
