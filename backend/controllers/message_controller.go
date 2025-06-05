package controllers

import (
	"fmt"
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
	result := mc.db.Preload("Sender").Where("(sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)",
		userID, otherUserID, otherUserID, userID,
	).Order("timestamp DESC").Limit(limit).Offset(offset).Find(&messages)

	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get messages"})
		return
	}

	c.JSON(http.StatusOK, messages)
}

// GetUnseenMessagesBWCount gets number of unseen message between 2 user.
func (mc *MessageController) GetUnseenMessagesBWCount(c *gin.Context) {
	userID := c.Param("userId")
	otherUserID := c.Param("otherUserId")

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

	// Only count unseen messages where the authenticated user is the receiver
	var count int64
	result := mc.db.Model(&models.Message{}).
		Where("sender_id = ? AND receiver_id = ? AND is_read = ?", otherUserID, userID, false).
		Count(&count)

	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to count unseen messages"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"unseen_count": count})
}

// GetUnseenMessagesALLCount gets number of unseen message between all user.
func (mc *MessageController) GetUnseenMessagesALLCount(c *gin.Context) {
	userID := c.Param("userId")

	// Get the authenticated user ID from the context
	authUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// Only allow the user to access their own unseen messages
	if authUserID != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "You can only access your own messages"})
		return
	}

	// Count all unseen messages where the user is the receiver
	var count int64
	result := mc.db.Model(&models.Message{}).
		Where("receiver_id = ? AND is_read = ?", userID, false).
		Count(&count)

	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to count unseen messages"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"unseen_count": count})
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
	//I am stopping it because we have already publishing from frontend
	//err := mc.mqttClient.PublishDirectMessage(&message)
	//if err != nil {
	// Log error but don't fail the request
	//log.Printf("Failed to publish message to MQTT: %v", err)
	//}

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
	//Commenting because we already did from frontend
	//err := mc.mqttClient.PublishGroupMessage(&message)
	//if err != nil {
	// Log error but don't fail the request
	//	log.Printf("Failed to publish message to MQTT: %v", err)
	//}

	// Load sender details
	mc.db.First(&message.Sender, "id = ?", message.SenderID)

	c.JSON(http.StatusCreated, message)
}

// MarkMessagesAsReadRequest represents the request body for marking messages as read
type MarkMessagesAsReadRequest struct {
	MessageIDs []string `json:"message_ids" binding:"required"`
}

// MarkMessagesAsRead marks one or more messages as read by the receiver
func (mc *MessageController) MarkMessagesAsRead(c *gin.Context) {
	// Get the authenticated user ID from the context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// Parse request body
	var req MarkMessagesAsReadRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Update messages where the receiver is the current user
	result := mc.db.Model(&models.Message{}).
		Where("id IN ? AND receiver_id = ?", req.MessageIDs, userID).
		Update("is_read", true)

	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to mark messages as read"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"updated": result.RowsAffected})
}

// DeleteMessage deletes a message (only by  messsage creator)
func (gc *MessageController) DeleteMessage(c *gin.Context) {
	messageID := c.Param("id")
	if messageID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Message ID is required"})
		return
	}

	// Get the authenticated user ID from the context
	authUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// Check if the group exists
	var message models.Message
	result := gc.db.First(&message, "id = ?", messageID)
	if result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "message not found"})
		return
	}

	// Only allow the creator/admin to delete the message
	if message.SenderID != authUserID {
		c.JSON(http.StatusForbidden, gin.H{"error": "Only the message creator can delete the message"})
		return
	}

	// Delete the messageID
	result = gc.db.Delete(&message)
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete message"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "message deleted successfully"})
}
