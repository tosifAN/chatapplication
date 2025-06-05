package controllers

import (
	"net/http"
	"time"

	"backend/models"
	"backend/mqtt"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

// GroupController handles group-related requests
type GroupController struct {
	db         *gorm.DB
	mqttClient *mqtt.MQTTClient
}

// NewGroupController creates a new group controller
func NewGroupController(db *gorm.DB, mqttClient *mqtt.MQTTClient) *GroupController {
	return &GroupController{db: db, mqttClient: mqttClient}
}

// CreateGroupRequest represents the request body for creating a group
type CreateGroupRequest struct {
	Name        string   `json:"name" binding:"required"`
	Description string   `json:"description"`
	MemberIDs   []string `json:"member_ids"`
}

// CreateGroup creates a new group
func (gc *GroupController) CreateGroup(c *gin.Context) {
	// Get the authenticated user ID from the context
	creatorID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// Parse request body
	var req CreateGroupRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Create group
	now := time.Now()
	groupID := uuid.New().String()
	description := req.Description
	group := models.Group{
		ID:          groupID,
		Name:        req.Name,
		Description: &description,
		CreatorID:   creatorID.(string),
		CreatedAt:   now,
		UpdatedAt:   now,
	}

	// Start a transaction
	tx := gc.db.Begin()
	if tx.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
		return
	}

	// Save group
	result := tx.Create(&group)
	if result.Error != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create group"})
		return
	}

	// Add creator as a member and admin
	creatorGroupUser := models.GroupUser{
		GroupID:   groupID,
		UserID:    creatorID.(string),
		JoinedAt:  now,
		IsAdmin:   true,
		CreatedAt: now,
		UpdatedAt: now,
	}

	result = tx.Create(&creatorGroupUser)
	if result.Error != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add creator to group"})
		return
	}

	// Add other members
	for _, memberID := range req.MemberIDs {
		// Skip if member ID is the same as creator ID
		if memberID == creatorID.(string) {
			continue
		}

		// Check if user exists
		var user models.User
		result = tx.First(&user, "id = ?", memberID)
		if result.Error != nil {
			continue // Skip if user doesn't exist
		}

		// Add user to group
		memberGroupUser := models.GroupUser{
			GroupID:   groupID,
			UserID:    memberID,
			JoinedAt:  now,
			IsAdmin:   false,
			CreatedAt: now,
			UpdatedAt: now,
		}

		result = tx.Create(&memberGroupUser)
		if result.Error != nil {
			// Log error but continue
			continue
		}
	}

	// Commit transaction
	if err := tx.Commit().Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit transaction"})
		return
	}

	// Load creator details
	gc.db.First(&group.Creator, "id = ?", group.CreatorID)

	// Load members
	var groupUsers []models.GroupUser
	gc.db.Preload("User").Where("group_id = ?", groupID).Find(&groupUsers)
	group.Members = groupUsers

	c.JSON(http.StatusCreated, group)
}

// GetGroup gets a group by ID
func (gc *GroupController) GetGroup(c *gin.Context) {
	groupID := c.Param("id")
	if groupID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Group ID is required"})
		return
	}

	// Get the authenticated user ID from the context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// Check if the group exists
	var group models.Group
	result := gc.db.Preload("Creator").First(&group, "id = ?", groupID)
	if result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Group not found"})
		return
	}

	// Check if the user is a member of the group
	var groupUser models.GroupUser
	result = gc.db.Where("group_id = ? AND user_id = ?", groupID, userID).First(&groupUser)
	if result.Error != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": "You are not a member of this group"})
		return
	}

	// Load members
	var groupUsers []models.GroupUser
	gc.db.Preload("User").Where("group_id = ?", groupID).Find(&groupUsers)
	group.Members = groupUsers

	c.JSON(http.StatusOK, group)
}

// UpdateGroupRequest represents the request body for updating a group
type UpdateGroupRequest struct {
	Name        *string `json:"name"`
	Description *string `json:"description"`
	AvatarURL   *string `json:"avatar_url"`
}

// UpdateGroup updates a group
func (gc *GroupController) UpdateGroup(c *gin.Context) {
	groupID := c.Param("id")
	if groupID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Group ID is required"})
		return
	}

	// Get the authenticated user ID from the context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// Parse request body
	var req UpdateGroupRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if the group exists
	var group models.Group
	result := gc.db.First(&group, "id = ?", groupID)
	if result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Group not found"})
		return
	}

	// Check if the user is an admin of the group
	var groupUser models.GroupUser
	result = gc.db.Where("group_id = ? AND user_id = ? AND is_admin = ?", groupID, userID, true).First(&groupUser)
	if result.Error != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": "You must be an admin to update the group"})
		return
	}

	// Update group fields if provided
	if req.Name != nil {
		group.Name = *req.Name
	}

	if req.Description != nil {
		group.Description = req.Description
	}

	if req.AvatarURL != nil {
		group.AvatarURL = req.AvatarURL
	}

	// Update timestamp
	group.UpdatedAt = time.Now()

	// Save group
	result = gc.db.Save(&group)
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update group"})
		return
	}

	// Load creator details
	gc.db.First(&group.Creator, "id = ?", group.CreatorID)

	// Load members
	var groupUsers []models.GroupUser
	gc.db.Preload("User").Where("group_id = ?", groupID).Find(&groupUsers)
	group.Members = groupUsers

	c.JSON(http.StatusOK, group)
}

// AddMemberRequest represents the request body for adding a member to a group
type AddMemberRequest struct {
	UserID string `json:"user_id" binding:"required"`
}

// AddMember adds a member to a group
func (gc *GroupController) AddMember(c *gin.Context) {
	groupID := c.Param("id")
	if groupID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Group ID is required"})
		return
	}

	// Get the authenticated user ID from the context
	authUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// Parse request body
	var req AddMemberRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if the group exists
	var group models.Group
	result := gc.db.First(&group, "id = ?", groupID)
	if result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Group not found"})
		return
	}

	// Check if the authenticated user is an admin of the group
	var adminGroupUser models.GroupUser
	result = gc.db.Where("group_id = ? AND user_id = ? AND is_admin = ?", groupID, authUserID, true).First(&adminGroupUser)
	if result.Error != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": "You must be an admin to add members"})
		return
	}

	// Check if the user to be added exists
	var user models.User
	result = gc.db.First(&user, "id = ?", req.UserID)
	if result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Check if the user is already a member of the group
	var existingGroupUser models.GroupUser
	result = gc.db.Where("group_id = ? AND user_id = ?", groupID, req.UserID).First(&existingGroupUser)
	if result.Error == nil {
		c.JSON(http.StatusConflict, gin.H{"error": "User is already a member of the group"})
		return
	}

	// Add user to group
	now := time.Now()
	groupUser := models.GroupUser{
		GroupID:   groupID,
		UserID:    req.UserID,
		JoinedAt:  now,
		IsAdmin:   false,
		CreatedAt: now,
		UpdatedAt: now,
	}

	result = gc.db.Create(&groupUser)
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add user to group"})
		return
	}

	// Send system message to group
	systemMessage := models.Message{
		ID:        uuid.New().String(),
		SenderID:  authUserID.(string),
		GroupID:   &groupID,
		Content:   user.Username + " has joined the group",
		Type:      models.SystemMessage,
		Timestamp: now,
		CreatedAt: now,
		UpdatedAt: now,
	}

	gc.db.Create(&systemMessage)
	gc.mqttClient.PublishGroupMessage(&systemMessage)

	c.JSON(http.StatusOK, gin.H{"message": "User added to group successfully"})
}

// RemoveMember removes a member from a group
func (gc *GroupController) RemoveMember(c *gin.Context) {
	groupID := c.Param("id")
	userID := c.Param("userId")

	if groupID == "" || userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Group ID and User ID are required"})
		return
	}

	// Get the authenticated user ID from the context
	authUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// Check if the group exists
	var group models.Group
	result := gc.db.First(&group, "id = ?", groupID)
	if result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Group not found"})
		return
	}

	// Check if the user is a member of the group
	var groupUser models.GroupUser
	result = gc.db.Where("group_id = ? AND user_id = ?", groupID, userID).First(&groupUser)
	if result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User is not a member of the group"})
		return
	}

	// Check if the authenticated user is the user being removed or an admin
	if authUserID != userID {
		var adminGroupUser models.GroupUser
		result = gc.db.Where("group_id = ? AND user_id = ? AND is_admin = ?", groupID, authUserID, true).First(&adminGroupUser)
		if result.Error != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "You must be an admin to remove other members"})
			return
		}

		// Don't allow removing the creator
		if userID == group.CreatorID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Cannot remove the group creator"})
			return
		}
	}

	// Remove user from group
	result = gc.db.Delete(&groupUser)
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to remove user from group"})
		return
	}

	// Get user details for system message
	var user models.User
	gc.db.First(&user, "id = ?", userID)

	// Send system message to group
	now := time.Now()
	systemMessage := models.Message{
		ID:        uuid.New().String(),
		SenderID:  authUserID.(string),
		GroupID:   &groupID,
		Content:   user.Username + " has left the group",
		Type:      models.SystemMessage,
		Timestamp: now,
		CreatedAt: now,
		UpdatedAt: now,
	}

	gc.db.Create(&systemMessage)
	gc.mqttClient.PublishGroupMessage(&systemMessage)

	c.JSON(http.StatusOK, gin.H{"message": "User removed from group successfully"})
}

// DeleteGroup deletes a group (only by admin/creator)
func (gc *GroupController) DeleteGroup(c *gin.Context) {
	groupID := c.Param("id")
	if groupID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Group ID is required"})
		return
	}

	// Get the authenticated user ID from the context
	authUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// Check if the group exists
	var group models.Group
	result := gc.db.First(&group, "id = ?", groupID)
	if result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Group not found"})
		return
	}

	// Only allow the creator/admin to delete the group
	if group.CreatorID != authUserID {
		c.JSON(http.StatusForbidden, gin.H{"error": "Only the group creator can delete the group"})
		return
	}

	// Delete all group users (memberships)
	gc.db.Where("group_id = ?", groupID).Delete(&models.GroupUser{})

	// Delete all group messages
	gc.db.Where("group_id = ?", groupID).Delete(&models.Message{})

	// Delete the group itself
	result = gc.db.Delete(&group)
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete group"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Group deleted successfully"})
}
